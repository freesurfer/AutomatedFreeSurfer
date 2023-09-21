### README

#### Description:
These scripts process T1 images in a BIDS-formatted dataset using FreeSurfer's recon-all and the hippocampal and amygdala subfields segmentation stream, create a quality control montage of the FreeSurfer output for each subject and session, and extract the metrics into a CSV file. It runs the longitudinal stream if there's more than one session per subject.

They were designed to run with minimal user input. You will be presented with a series of questions that you need to answer in order to start specific processes. 

#### Author:
- Carolina Ferreira-Atuesta (September 2023)
- Email: cfatuesta@gmail.com

#### Prerequisites:
- Dataset must be organized according to the BIDS specification, including correctly named main directory and subdirectories.
  ![Image 18-09-2023 at 07 47](https://github.com/cfatuesta/ENIGMA/assets/42354106/2b7a68fc-4eb7-4d45-9283-e2142f4b0859)
- FreeSurfer must be installed, and the following scripts should be in your `SUBJECTS_DIR` path: `process_csv.py`, `merge_csv.py`, and `process_longitudinal.py`.
- FreeSurfer's `freeview` and ImageMagick's `magick` command should be available in your system. To install ImageMagick, you can run: `brew install imagemagick`.
- Make sure you have python3 installed. Run `python --version` from your terminal to check which version you have. If its not python3, run:
  - `brew install pyenv`
  - `pyenv install 3.10.10`
  - `pyenv global 3.10.10`

** if you don't have homebrew (needed to be able to execute the "brew" commands) installed, run this before installing any package:
  - `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

#### Instructions:

1. **Starting the Main Script**:
   Run the script `main_script.sh` in your terminal. If the dataset isn't organized and named correctly, press `Ctrl+C` to exit. Otherwise, press `Enter` to continue.

2. **Enter Paths**:
   - If `SUBJECTS_DIR` and `FREESURFER_HOME` are not set, you will be prompted to enter the paths to the SUBJECTS dataset and Freesurfer installation.
   - If they are set, confirm or re-enter the paths.

3. **Processing T1 Images**:
   - The script will display all found T1 images and ask whether to process the images through the cross-sectional pipeline. Type `yes` to proceed.

4. **Generating Montages**:
   - If there are T1 images without montages, the script will ask whether to generate montages for these images. Type `yes` to proceed.
   - Two montages are generated for each subject/session - see below for examples:
     ![montage-3d](https://github.com/cfatuesta/ENIGMA/assets/42354106/15cd17f8-269a-4f8a-9953-2d88a9b00b8d)
      ![montage-2d](https://github.com/cfatuesta/ENIGMA/assets/42354106/82049d88-13a3-4ab8-963a-92ca5d40575d)


5. **Tables Creation**:
   - The script will create tables with all the cross-sectional and longitudinal data if available.
   - See the image below for an example of a generated file. 
   
      <img width="901" alt="Screenshot 2023-09-21 at 09 52 23" src="https://github.com/cfatuesta/ENIGMA/assets/42354106/9be972e4-eb75-48de-89ce-ddd4bff44b1b">

7. **Longitudinal stream**:
   - The script checks if there is more than 1 session per subject with already processed T1s.
   - If this is satisfied, the script will run Freesurfer's longitudinal pipeline, creating new folders for each output (base, time 1, and time 2)

#### Usage Example:
```sh
bash main_script.sh 
```

#### Output:
- Quality control montage for each subject and session.
- Metrics extracted into a CSV file.
- Longitudinal stream data if there's more than one session per subject.

#### Notes:
- Do not change the names of the required scripts in your `SUBJECTS_DIR` path.
- Always make sure that the paths entered are correct to avoid errors.
- Ensure your dataset is well-organized and correctly named, following the BIDS specification, before running the script.

#### Troubleshooting:
- If the `freeview` or `magick` commands are not found, follow the error message instructions to install the missing software.
- If entered paths do not exist or are not directories, you will receive an error message, and the script will exit. Double-check your paths and try again.

#### Contact:
For any questions or issues, please contact Carolina Ferreira-Atuesta at cfatuesta@gmail.com.
