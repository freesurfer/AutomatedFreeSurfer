import os
import subprocess
import shutil
import sys


def create_symlinks(subject, base_path):
    """Create symlinks for ses-01 and ses-02 directories."""
    target_ses01 = os.path.join(base_path, subject, "ses-01", "derivatives", subject)
    target_ses02 = os.path.join(base_path, subject, "ses-02", "derivatives", subject)

    symlink_ses01 = os.path.join(base_path, subject, subject + "_ses-01")
    symlink_ses02 = os.path.join(base_path, subject, subject + "_ses-02")

    os.symlink(target_ses01, symlink_ses01)
    os.symlink(target_ses02, symlink_ses02)


def run_longitudinal_pipeline(subject, base_path):
    """Run the longitudinal pipeline for a given subject."""
    print(f"Creating base for {subject}")

    base_cmd = [
        "recon-all",
        "-base",
        os.path.join(base_path, f"{subject}_base"),
        "-tp",
        os.path.join(base_path, subject, subject + "_ses-01"),
        "-tp",
        os.path.join(base_path, subject, subject + "_ses-02"),
        "-all",
        "-sd",
        os.path.join(base_path, subject),
    ]

    result = subprocess.run(base_cmd)
    if result.returncode != 0:
        print(f"Error with recon-all for {subject}")
        exit(1)

    # Continue with the rest of the pipeline for ses-01 and ses-02 using the symlinks
    for session in ["ses-01", "ses-02"]:
        print(f"Running longitudinal pipeline for {subject} {session}")
        long_cmd = [
            "recon-all",
            "-long",
            os.path.join(base_path, subject, subject + "_" + session),
            os.path.join(base_path, subject, subject + "_base"),
            "-all",
            "-sd",
            os.path.join(base_path, subject),
        ]
        result = subprocess.run(long_cmd)
        if result.returncode != 0:
            print(f"Error with recon-all for {subject} {session}")
            exit(1)


def cleanup_and_move_files(subject, base_path):
    """
    Delete the created symlinks and move the newly generated folders
    based on the naming conventions to the respective session/derivatives/longitudinal.
    """
    symlink_ses01_path = os.path.join(base_path, subject, subject + "_ses-01")
    symlink_ses02_path = os.path.join(base_path, subject, subject + "_ses-02")

    # Delete symlinks if they exist
    if os.path.islink(symlink_ses01_path):
        os.unlink(symlink_ses01_path)
    if os.path.islink(symlink_ses02_path):
        os.unlink(symlink_ses02_path)

    # Go through folders in the base_path and move based on the naming conventions

    # Go to subject folder

    for folder in os.listdir(os.path.join(base_path, subject)):
        print("folder", folder)
        folder_path = os.path.join(base_path, subject, folder)

        if os.path.isdir(folder_path):
            print("folder_path", folder_path)
            # if folder name contains "long" and "ses-01" or "ses-02"
            if ".long." in folder and ("_ses-01" in folder or "_ses-02" in folder):
                # if folder name has "ses-01", move the contents to target dir
                if "ses-01" in folder:
                    target_dir = os.path.join(
                        base_path, subject, "ses-01", "derivatives", "longitudinal"
                    )
                    os.makedirs(target_dir, exist_ok=True)
                    shutil.move(folder_path, target_dir)
                # if folder name has "ses-02", move the contents to target dir
                elif "ses-02" in folder:
                    target_dir = os.path.join(
                        base_path, subject, "ses-02", "derivatives", "longitudinal"
                    )
                    os.makedirs(target_dir, exist_ok=True)
                    shutil.move(folder_path, target_dir)
            # if folder name contains "base" and NOT long
            elif "_base" in folder and ".long." not in folder:
                # move the contents to target dir
                target_dir = os.path.join(
                    base_path, subject, "ses-01", "derivatives", "longitudinal"
                )
                os.makedirs(target_dir, exist_ok=True)
                shutil.move(folder_path, target_dir)

def process_longitudinal(subject_dir):
    subject = os.path.basename(subject_dir)
    base_path = os.path.dirname(subject_dir)

    print(f"Processing {subject}")

    create_symlinks(subject, base_path)
    run_longitudinal_pipeline(subject, base_path)
    cleanup_and_move_files(subject, base_path)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python process_longitudinal.py <subject_dir>")
        sys.exit(1)

    subject_dir = sys.argv[1]
    process_longitudinal(subject_dir)

