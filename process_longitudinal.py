import os
import subprocess
     

def run_longitudinal_pipeline(long_sub, SUBJECTS_DIR):
    """Run the longitudinal pipeline for a given subject."""
    
    print(f"Creating base for {long_sub}")

    
    #Running the base command
    # base_cmd = [
    #     "recon-all", "-base", os.path.join(base_dir, f"{long_sub}_base"),
    #     "-tp", os.path.join(SUBJECTS_DIR, long_sub, "ses-1", "derivatives", long_sub),
    #     "-tp", os.path.join(SUBJECTS_DIR, long_sub, "ses-2", "derivatives", long_sub),
    #     "-all", "-sd", os.path.join(SUBJECTS_DIR, long_sub)
    # ]
    # result = subprocess.run(base_cmd)
    
    # if result.returncode != 0:
    #     print(f"Error with recon-all for {long_sub}")
    #     exit(1)

    #create a copy of the base folder in ses-2/derivatives
    print(f"Copying base for {long_sub} ses-2")
    base_dir = os.path.join(SUBJECTS_DIR, long_sub, "ses-1", "derivatives", long_sub + "_base")
    ses2_dir = os.path.join(SUBJECTS_DIR, long_sub, "ses-2", "derivatives")
    result = subprocess.run(["cp", "-r", base_dir, ses2_dir])

    
    # Running the longitudinal pipeline for ses-1
    # print(f"Running longitudinal pipeline for {long_sub} ses-1")
    # base_dir = os.path.join(SUBJECTS_DIR, long_sub, long_sub + "_base")

    # long_cmd_ses1 = [
    #     "recon-all", "-long", os.path.join(SUBJECTS_DIR, long_sub, "ses-1", "derivatives", long_sub),  base_dir,  "-all", "-sd", os.path.join(SUBJECTS_DIR, long_sub, "ses-1", "derivatives")
    # ]
    # print(long_cmd_ses1)
    
    # result = subprocess.run(long_cmd_ses1)
    
    # if result.returncode != 0:
    #     print(f"Error with recon-all for {long_sub}")
    #     exit(1)
    
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

def process_longitudinal(SUBJECTS_DIR):
    for subject in os.listdir(SUBJECTS_DIR):
        # Check that the subject is a folder and the name has "sub-" in it
        subject_dir = os.path.join(SUBJECTS_DIR, subject)
        if not os.path.isdir(subject_dir) or 'sub-' not in subject:
            continue

        #if subject_dir has a subfolder called ses-01 and ses-02 and both have a derivatives folder, then run the longitudinal pipeline
        ses_01_output = os.path.exists(os.path.join(subject_dir, "ses-1", "derivatives", subject))
        ses_02_output = os.path.exists(os.path.join(subject_dir, "ses-2", "derivatives", subject))

        if ses_01_output and ses_02_output:
            run_longitudinal_pipeline(subject, SUBJECTS_DIR)
        else:
            print(f"Scans for {subject} have not been processed through freesurfer. Skipping longitudinal pipeline.")

if __name__ == '__main__':
    import sys
    if len(sys.argv) < 2:
        print("Usage: python process_longitudinal.py <SUBJECTS_DIR>")
        sys.exit(1)

    SUBJECTS_DIR = sys.argv[1]
    process_longitudinal(SUBJECTS_DIR)
