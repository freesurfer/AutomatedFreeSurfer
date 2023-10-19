import os
import subprocess
import shutil
import sys
     

def run_longitudinal_pipeline(long_sub, SUBJECTS_DIR):
    """Run the longitudinal pipeline for a given subject."""
    
    print(f"Creating base for {long_sub}")

    # Running the base command
    base_cmd = [
        "recon-all", "-base", os.path.join(base_dir, f"{long_sub}_base"),
        "-tp", os.path.join(SUBJECTS_DIR, long_sub, "ses-1", "derivatives", long_sub),
        "-tp", os.path.join(SUBJECTS_DIR, long_sub, "ses-2", "derivatives", long_sub),
        "-all", "-sd", os.path.join(SUBJECTS_DIR, long_sub)
    ]
    result = subprocess.run(base_cmd)
    
    if result.returncode != 0:
        print(f"Error with recon-all for {long_sub}")
        exit(1)

    # Create a copy of the base folder in ses-2/derivatives
    print(f"Copying base for {long_sub} ses-2")
    base_dir = os.path.join(SUBJECTS_DIR, long_sub, "ses-1", "derivatives", long_sub + "_base")
    ses2_dir = os.path.join(SUBJECTS_DIR, long_sub, "ses-2", "derivatives")
    result = subprocess.run(["cp", "-r", base_dir, ses2_dir])

    
    # Running the longitudinal pipeline for ses-1
    print(f"Running longitudinal pipeline for {long_sub} ses-1")
    base_dir = os.path.join(SUBJECTS_DIR, long_sub, long_sub + "_base")

    long_cmd_ses1 = [
        "recon-all", "-long", os.path.join(SUBJECTS_DIR, long_sub, "ses-1", "derivatives", long_sub),  base_dir,  "-all", "-sd", os.path.join(SUBJECTS_DIR, long_sub, "ses-1", "derivatives")
    ]
    print(long_cmd_ses1)
    
    result = subprocess.run(long_cmd_ses1)
    
    if result.returncode != 0:
        print(f"Error with recon-all for {long_sub}")
        exit(1)
    
    # Running the longitudinal pipeline for ses-2
    print(f"Running longitudinal pipeline for {long_sub} ses-2")
    base_dir = os.path.join(SUBJECTS_DIR, long_sub, long_sub + "_base")

    long_cmd_ses2 = [
        "recon-all", "-long", os.path.join(SUBJECTS_DIR, long_sub, "ses-2", "derivatives", long_sub),  base_dir,  "-all", "-sd", os.path.join(SUBJECTS_DIR, long_sub, "ses-2", "derivatives")
    ]
    result = subprocess.run(long_cmd_ses2)
    
    if result.returncode != 0:
        print(f"Error with recon-all for {long_sub}")
        exit(1)


def cleanup_and_move_files(SUBJECTS_DIR, subject):
    """
    Delete the created symlinks and move the newly generated folders
    based on the naming conventions to the respective session/derivatives/longitudinal.
    """
    # Define symlinks paths
    symlink_ses_01_path = os.path.join(SUBJECTS_DIR, subject + "_ses-01")
    symlink_ses_02_path = os.path.join(SUBJECTS_DIR, subject + "_ses-02")
    
    # Delete symlinks if they exist
    if os.path.islink(symlink_ses_01_path):
        os.unlink(symlink_ses_01_path)
    if os.path.islink(symlink_ses_02_path):
        os.unlink(symlink_ses_02_path)
    
    # Go through folders in the SUBJECTS_DIR and move based on the naming conventions
    for folder in os.listdir(SUBJECTS_DIR):
        # Define the full path of the folder
        folder_path = os.path.join(SUBJECTS_DIR, folder)
        
        # Check if it's a directory
        if os.path.isdir(folder_path):
            if "_ses-01" in folder or "_ses-02" in folder:
                if ".long." in folder:
                    target_dir = os.path.join(SUBJECTS_DIR, folder.split("_")[1], "derivatives", "longitudinal")
                    os.makedirs(target_dir, exist_ok=True)
                    shutil.move(folder_path, target_dir)
                elif "_base" in folder:
                    target_dir = os.path.join(SUBJECTS_DIR, "ses-01", "derivatives", "longitudinal")
                    shutil.move(folder_path, target_dir)


def process_longitudinal(subject_dir, SUBJECTS_DIR):
    # Extract the subject name
    subject = os.path.basename(subject_dir)

    # If subject_dir has a subfolder called ses-01 and ses-02 and both have a derivatives folder, then run the longitudinal pipeline
    ses_01_output = os.path.exists(os.path.join(subject_dir, "ses-1", "derivatives", subject))
    ses_02_output = os.path.exists(os.path.join(subject_dir, "ses-2", "derivatives", subject))

    if ses_01_output and ses_02_output:
        run_longitudinal_pipeline(subject, SUBJECTS_DIR)
        cleanup_and_move_files(SUBJECTS_DIR, subject)
    else:
        print(f"Scans for {subject} have not been processed through freesurfer. Skipping longitudinal pipeline.")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python process_longitudinal.py <SUBJECTS_DIR>")
        sys.exit(1)

    # Accept specific subject directory as an argument
    subject_dir = sys.argv[1]
    # Extract the main SUBJECTS_DIR from the specific subject directory
    SUBJECTS_DIR = os.path.dirname(subject_dir)

    process_longitudinal(subject_dir, SUBJECTS_DIR)
