#!/usr/bin/env python3
"""
Build Docker images via Cloud Build and return digests for Terraform.
Designed to work with Terraform's data.external resource.

This script provides a reusable way to build Docker images using Cloud Build
with branch-based caching and digest tracking for Terraform.
"""

import json
import os
import subprocess
import sys


def run_command(cmd, **kwargs):
    """Run a command and return the result."""
    print(f"+ {' '.join(cmd)}", file=sys.stderr)
    try:
        return subprocess.run(cmd, check=True, capture_output=True, text=True, **kwargs)
    except subprocess.CalledProcessError as e:
        print(f"Command failed with exit code {e.returncode}", file=sys.stderr)
        if e.stdout:
            print(f"stdout:\n{e.stdout}", file=sys.stderr)
        if e.stderr:
            print(f"stderr:\n{e.stderr}", file=sys.stderr)
        raise


def get_image_digest(image_uri, tag, project_id):
    """Query the digest of an existing image."""
    try:
        result = run_command(
            [
                "gcloud",
                "container",
                "images",
                "list-tags",
                image_uri,
                "--filter",
                f"tags:{tag}",
                "--limit",
                "1",
                "--format=get(digest)",
                "--project",
                project_id,
            ]
        )
        digest = result.stdout.strip()
        if digest:
            return f"{image_uri}@{digest}"
        return None
    except subprocess.CalledProcessError:
        return None


def check_cache_tag_exists(image_uri, cache_tag, project_id):
    """Check if a cache tag exists for the given image."""
    try:
        result = run_command(
            [
                "gcloud",
                "container",
                "images",
                "list-tags",
                image_uri,
                "--filter",
                f"tags:{cache_tag}",
                "--limit",
                "1",
                "--format=get(digest)",
                "--project",
                project_id,
            ]
        )
        return bool(result.stdout.strip())
    except subprocess.CalledProcessError:
        return False


def get_effective_cache_tag(image_uri, image_tag_suffix, project_id):
    """Determine the effective cache tag, falling back to 'latest' if the provided tag doesn't exist."""
    # First check if the provided cache tag exists
    if check_cache_tag_exists(image_uri, image_tag_suffix, project_id):
        print(f"Using cache tag: {image_tag_suffix}", file=sys.stderr)
        return image_tag_suffix
    
    # Fall back to 'latest' if the provided tag doesn't exist
    print(f"Cache tag '{image_tag_suffix}' not found, falling back to 'latest'", file=sys.stderr)
    return "latest"


def build_image(
    image_name,
    context_path,
    dockerfile_path,
    project_id,
    image_tag_suffix,
    base_digest="latest",
):
    """Build a Docker image via Cloud Build and return its digest."""

    # Construct image URIs
    image_uri = f"gcr.io/{project_id}/{image_name}"
    image_tag = f"{image_uri}:{image_tag_suffix}"

    print(f"Building image: {image_name} with tag: {image_tag_suffix}", file=sys.stderr)

    # Determine the effective cache tag
    effective_cache_tag = get_effective_cache_tag(image_uri, image_tag_suffix, project_id)

    # Handle Dockerfile symlink if needed
    # The symlinking logic allows using Dockerfiles with:
    # - Custom names (e.g., listener.Dockerfile, base.Dockerfile)
    # - Different locations (e.g., ../dockerfiles/runner.Dockerfile)
    # Since Cloud Build expects Dockerfile in the build context, the code temporarily
    # creates a symlink /Dockerfile → <actual_dockerfile>, builds the image, then cleans up
    # the symlink. This is a workaround to allow using Dockerfiles with custom names and locations.

    symlink_path = None
    if dockerfile_path and dockerfile_path not in ["Dockerfile", "./Dockerfile"]:
        # Check if dockerfile is relative to context (no symlink needed)
        dockerfile_in_context = os.path.join(context_path, dockerfile_path)
        context_dockerfile = os.path.join(context_path, "Dockerfile")

        if os.path.exists(dockerfile_in_context):
            # Dockerfile exists relative to context, create symlink to standard name
            print(
                f"Creating symlink: {context_dockerfile} -> {dockerfile_path}",
                file=sys.stderr,
            )
            symlink_path = context_dockerfile
            if os.path.exists(symlink_path):
                os.unlink(symlink_path)
            os.symlink(dockerfile_path, symlink_path)
        else:
            # Try absolute dockerfile path and create relative symlink
            if os.path.exists(dockerfile_path):
                rel_path = os.path.relpath(dockerfile_path, context_path)
                print(
                    f"Creating symlink: {context_dockerfile} -> {rel_path}",
                    file=sys.stderr,
                )
                symlink_path = context_dockerfile
                if os.path.exists(symlink_path):
                    os.unlink(symlink_path)
                os.symlink(rel_path, symlink_path)
            else:
                raise FileNotFoundError(
                    f"Dockerfile not found: {dockerfile_path} (relative to context) or {dockerfile_in_context} (absolute)"
                )

    try:
        # Prepare Cloud Build substitutions (no quotes around values)
        substitutions = {
            "_IMAGE_NAME": image_uri,
            "_IMAGE_TAG": image_tag,
            "_BASE_DIGEST": base_digest,
            "_CACHE_TAG": effective_cache_tag,  # Use effective cache tag (with fallback to latest)
        }
        subs_str = ",".join(f"{k}={v}" for k, v in substitutions.items())

        # Submit to Cloud Build
        # Get the directory where this script is located to find cloudbuild.yml
        script_dir = os.path.dirname(os.path.abspath(__file__))
        cloudbuild_config = os.path.join(script_dir, "cloudbuild.yml")
        
        # TODO(jwbron): Consider adding automatic GCS bucket creation with import support for existing buckets in terraform
        run_command(
            [
                "gcloud",
                "builds",
                "submit",
                context_path,
                f"--config={cloudbuild_config}",
                f"--project={project_id}",
                f"--gcs-source-staging-dir=gs://{project_id}-cloudbuild-ci/staging",
                f"--gcs-log-dir=gs://{project_id}-cloudbuild-ci/logs",
                f"--substitutions={subs_str}",
            ]
        )

        # Query the digest of the newly built image
        digest = get_image_digest(image_uri, image_tag_suffix, project_id)
        if not digest:
            raise RuntimeError(
                f"Failed to get digest for {image_tag} after successful build"
            )

        print(f"Successfully built: {digest}", file=sys.stderr)
        return digest

    finally:
        # Clean up symlink
        if symlink_path and os.path.islink(symlink_path):
            print(f"Cleaning up symlink: {symlink_path}", file=sys.stderr)
            os.unlink(symlink_path)


def main():
    """Main function for Terraform data.external integration."""
    try:
        # Read JSON input from Terraform
        input_data = json.load(sys.stdin)

        # Extract parameters
        image_name = input_data["image_name"]
        context_path = input_data["context"]
        dockerfile_path = input_data.get("dockerfile", None)
        project_id = input_data["project_id"]
        image_tag_suffix = input_data["image_tag_suffix"]
        base_digest = input_data.get("base_digest", "latest")

        # Validate that image_tag_suffix is not empty
        if not image_tag_suffix or image_tag_suffix.strip() == "":
            raise ValueError("image_tag_suffix cannot be empty or whitespace")

        # Build the image and get digest
        digest = build_image(
            image_name=image_name,
            context_path=context_path,
            dockerfile_path=dockerfile_path,
            project_id=project_id,
            image_tag_suffix=image_tag_suffix,
            base_digest=base_digest,
        )

        # Return JSON output for Terraform
        output = {"digest": digest}
        print(json.dumps(output))

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
