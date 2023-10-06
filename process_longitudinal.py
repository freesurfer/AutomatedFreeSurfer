import os
import subprocess

def create_symlinks(SUBJECTS_DIR, subject):
    """Create symlinks for ses-01 and ses-02 derivatives in SUBJECTS_DIR"""
    
    # Define the original paths for ses-01 and ses-02
    orig_ses_01_path = os.path.join(SUBJECTS_DIR, "ses-01", "derivatives", subject)
    orig_ses_02_path = os.path.join(SUBJECTS_DIR, "ses-02", "derivatives", subject)
    
    # Define the target paths for symlinks
    target_longitudinal_dir = os.path.join(SUBJECTS_DIR)
    os.makedirs(target_longitudinal_dir, exist_ok=True)
    target_ses_01_path = os.path.join(target_longitudinal_dir, subject + "_ses-01")
    target_ses_02_path = os.path.join(target_longitudinal_dir, subject + "_ses-02")
    
    # Create the symlinks
    os.symlink(orig_ses_01_path, target_ses_01_path)
    os.symlink(orig_ses_02_path, target_ses_02_path)
    print(f"Symlinks created for {subject} ses-01 and ses-02 in {target_longitudinal_dir}")

def run_longitudinal_pipeline(SUBJECTS_DIR):
    """Run the longitudinal pipeline for the current subject using the symlink directories."""
    
    subject = os.path.basename(SUBJECTS_DIR)
    print(f"Creating base for {subject}")
    longitudinal_dir = os.path.join(SUBJECTS_DIR)
    base_dir_1 = os.path.join(SUBJECTS_DIR, subject + "_ses-01")
    base_dir_2 = os.path.join(SUBJECTS_DIR, subject + "_ses-02")
    base_output_dir = os.path.join(SUBJECTS_DIR, f"{subject}_base")

    # Running the base command
    base_cmd = [
        "recon-all", "-base", base_output_dir,
        "-tp", base_dir_1,
        "-tp", base_dir_2,
        "-all"
    ]

    print(base_cmd)
    result = subprocess.run(base_cmd)
    
    if result.returncode != 0:
        print(f"Error with recon-all for {subject}")
        exit(1)

    # Running the longitudinal pipeline for ses-01
    print(f"Running longitudinal pipeline for {subject} ses-01")
    long_cmd_ses1 = [
        "recon-all", "-long", base_dir_1, base_output_dir, "-all", "-sd", longitudinal_dir
    ]
    print(long_cmd_ses1)
    result = subprocess.run(long_cmd_ses1)
    if result.returncode != 0:
        print(f"Error with recon-all for {subject} ses-01")
        exit(1)
    
    # Running the longitudinal pipeline for ses-02
    print(f"Running longitudinal pipeline for {subject} ses-02")
    long_cmd_ses2 = [
        "recon-all", "-long", base_dir_2, base_output_dir, "-all", "-sd", longitudinal_dir
    ]
    print(long_cmd_ses2)
    result = subprocess.run(long_cmd_ses2)
    if result.returncode != 0:
        print(f"Error with recon-all for {subject} ses-02")
        exit(1)

def process_longitudinal(SUBJECTS_DIR):
    subject = os.path.basename(SUBJECTS_DIR)

    # If SUBJECTS_DIR has subfolders called ses-01 and ses-02 and both have a derivatives folder, then create symlinks and run the longitudinal pipeline
    ses_01_output = os.path.exists(os.path.join(SUBJECTS_DIR, "ses-01", "derivatives", subject))
    ses_02_output = os.path.exists(os.path.join(SUBJECTS_DIR, "ses-02", "derivatives", subject))

    if ses_01_output and ses_02_output:
        create_symlinks(SUBJECTS_DIR, subject)
        run_longitudinal_pipeline(SUBJECTS_DIR)
    else:
        print(f"Scans for {subject} have not been processed through freesurfer. Skipping longitudinal pipeline.")

if __name__ == '__main__':
    import sys
    if len(sys.argv) < 2:
        print("Usage: python process_longitudinal.py <SUBJECTS_DIR>")
        sys.exit(1)

    SUBJECTS_DIR = sys.argv[1]
    process_longitudinal(SUBJECTS_DIR)

