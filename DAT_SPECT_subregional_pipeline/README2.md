# DAT-SPECT Processing & SBR Pipeline

This repository contains MATLAB scripts for preprocessing DaT-SPECT scans and computing striatal binding ratios (SBR). The pipeline includes co-registration to an MNI DaT template (SPM12), reslicing ROI masks to each subject's DaT-SPECT grid, and SBR computation using the superior longitudinal fasciculus (SLF; white-matter) as the reference region, with the occipital mean also reported for comparison with prior analyses.

**Note:** While developed using PPMI data, this pipeline can be applied to other DaT-SPECT datasets.

## Setup Instructions

### Required Mask Files
The `masks/` folder contains standard neuroimaging masks required for the analysis. **These files are not included in the repository due to size limitations** and must be obtained separately.

1. **Download required files:** Ensure you have access to all .nii mask files (see list below)
2. **Place files in `masks/`:** Copy all required .nii files to the masks folder
3. **Verify setup:** Check that all files listed in the folder layout are present

Required .nii files:
   - `symFPCITtemplate_MNI_norm.nii` (Standard MNI DaT template)
   - `JHU-SLF-binary.nii` (Superior longitudinal fasciculus mask from JHU atlas)
   - `fOccipital_bin.nii` (Occipital cortex reference region)
   - Striatal masks: `aCAU_lh_bin.nii`, `aCAU_rh_bin.nii`, etc. (from ATAG atlas)
   - Substantia nigra masks: `SN_L_binary.nii`, `SN_R_binary.nii`

**Note:** These are standard neuroanatomical masks in MNI space, suitable for any DaT-SPECT study after proper co-registration. These files can be downloaded from the [original MJFF repository](https://github.com/MJFF-ResearchCommunity/Imaging/tree/c3fa584c28909d0eea2966856175fcd74b846e81/DAT_SPECT_subregional_pipeline/masks).

## Usage

### MATLAB
```matlab
% In MATLAB (paths are already set in the scripts; update if needed):

flip;                                   % 1) create *_flippedZ.nii in each subject folder
coregister;                            % 2) write r*_flippedZ.nii in the template grid
reslice_masks;                         % 3) reslice masks → <subject>/resliced_masks/
extract_means_SBR_all_patients;        % 4) export PPMI_SBR_SLF.xlsx with live SBR formulas
```

## Expected Folder Layout

```
├─ spm12/
├─ masks/                                   # ⚠️  Ensure all .nii mask files are present
│   ├─ symFPCITtemplate_MNI_norm.nii        # MNI DaT template (coreg reference)
│   ├─ JHU-SLF-binary.nii                  # SLF reference mask
│   ├─ fOccipital_bin.nii                  # Occipital mask (reported only)
│   ├─ aCAU_lh_bin.nii  aCAU_rh_bin.nii
│   ├─ aPUT_lh_bin.nii  aPUT_rh_bin.nii
│   ├─ pCAU_lh_bin.nii  pCAU_rh_bin.nii
│   ├─ pPUT_lh_bin.nii  pPUT_rh_bin.nii
│   ├─ SN_L_binary.nii  SN_R_binary.nii
│
└─ coregistered_DAT/
    ├─ 101143/   *.nii  (raw SPECT)  r*_flippedZ.nii  resliced_masks/ (filled later)
    ├─ 10xxxx/   ...
    └─ ...
```

## Scripts

### 1) `flip.m`
- Scans each subject folder under `coregistered_DAT`, flips all `.nii` along Z, and saves as `*_flippedZ.nii`.
- Skips files already containing `flippedZ` in the name.

### 2) `coregister.m`
- Coregisters to the DaT template: `masks/symFPCITtemplate_MNI_norm.nii`.
- Writes resliced images `r*_flippedZ.nii` in the template grid.
- Includes a center-of-mass origin reset to stabilize SPM's optimization.

### 3) `reslice_masks()` (function)
- For each subject, selects a target SPECT:
  - Prefer: `r*flippedZ.nii`
  - Else: `r*BRAIN_SPECT*.nii`
- Reslices binary masks (nearest-neighbor) to the target SPECT grid via SPM Coreg: Write.

### 4) `extract_means_SBR_all_patients()` (function)
- Reads the SPECT image (same selection logic as above) and each resliced mask.
- Computes mean counts inside each ROI.
- Uses SLF mean as the SBR reference; also reports Occipital mean.
- Exports `SBR_SLF.xlsx` (sheet: `SBR`) with live Excel formulas for each SBR column:

```
SBR_ROI = (Mean_ROI − Mean_SLF) / Mean_SLF
```

- Columns include:
  - `SubjectID`, `Mean_WM_SLF_ref`, `Mean_Occ_ref`
  - `Mean_aCAU_lh_bin`, `Mean_aCAU_rh_bin`, …, `Mean_SN_R_binary`
  - `SBR_aCAU_lh_bin`, `SBR_aCAU_rh_bin`, …, `SBR_SN_R_binary`

## Troubleshooting

### Missing Mask Files
If you encounter errors about missing .nii files in `masks/`, verify that all required mask files are present. The pipeline will fail if any of the following are missing:
- Template file: `symFPCITtemplate_MNI_norm.nii` (standard DaT template)
- Reference masks: `JHU-SLF-binary.nii`, `fOccipital_bin.nii`
- ROI masks: All striatal and substantia nigra binary masks (derived from standard atlases)

**Note:** Due to file size limitations, .nii mask files are not included in this repository. You will need to:
1. Obtain the mask files from the original data source
2. Generate them using the referenced atlases (see "Atlases Used" section)
3. Contact the authors for access to the specific mask files used

## Software & Versions

- MATLAB (tested with R2022b+)
- SPM12 on MATLAB path
- **Note:** The pipeline performs Z-flip, which might be needed to pre-process the PPMI scans.

## Credits

- Braah Krayem (Project Developer): braah.krayem27@gmail.com
- Dr. Amgad Droby (Academic Supervisor): amgadd@tlvmc.gov.il
- Prof. Anat Mirelman (Research Collaboration): anatmi@tlvmc.gov.il

## Atlases Used

- [ATAG Atlas (Anatomical Atlas of the Striatum)](https://www.nitrc.org/projects/atag/)  
- [Tian 2020 Subcortical Atlas (v1.4 Download)](https://www.nitrc.org/frs/download.php/13364/Tian2020MSA_v1.4.zip)


---

## Use Example
The following is an example of how to use the pipeline in a specific HPC environment.  
All commands should be executed from the `DAT_SPECT_subregional_pipeline` directory.

### Download the PPMI data (DICOM)
```bash
mkdir -p coregistered_DAT
mkdir -p priv # to store raw PPMI dicom files
module load dcm2niix # PPMI data provided as dcm - need to convert to nii
# download the raw DAT images from PPMI website and place in priv folder
ls ./priv/PPMI_dicom/*/*/*/*/*.dcm # identify the dicom paths
```

### Convert DICOM files to NIfTI and organize by patient ID
```bash
# Automatically discover patient IDs from folder structure
patient_ids=($(ls -1 ./priv/PPMI_dicom/ | sort))

for patient_id in "${patient_ids[@]}"; do
    echo "Processing patient $patient_id"
    
    # Create output directory
    mkdir -p ./coregistered_DAT/$patient_id
    
    # Find the DICOM directory for this patient
    dcm_dir=$(find ./priv/PPMI_dicom/$patient_id -name "*.dcm" -printf '%h\n' | head -1)
    
    if [ -n "$dcm_dir" ]; then
        echo "Converting DICOM files from: $dcm_dir"
        # Convert DICOM to NIfTI using dcm2niix
        dcm2niix -o ./coregistered_DAT/$patient_id -f $patient_id "$dcm_dir"
        echo "Conversion completed for patient $patient_id"
    else
        echo "No DICOM files found for patient $patient_id"
    fi
done
```

### Environment setup (adjust as needed)
```bash
module load matlab/2023a
module load matlab-spm # instead of downloading the software, load the pre-installed module
```

### Run the pipeline
```bash
# Create logs directory
mkdir -p ./scripts/logs

matlab -batch "spm('defaults', 'FMRI'); \
spm_jobman('initcfg'); \
addpath('./scripts'); \
flip_nii('./coregistered_DAT', './scripts/logs/flip_nii.log'); \
coregister('./coregistered_DAT', './masks/symFPCITtemplate_MNI_norm.nii', './scripts/logs/coregister.log'); \
reslice_masks('./coregistered_DAT', './masks', './scripts/logs/reslice_mask.log'); \
extract_means_SBR_all_patients('./coregistered_DAT', './results.csv', './scripts/logs/extract_SBR.log');"