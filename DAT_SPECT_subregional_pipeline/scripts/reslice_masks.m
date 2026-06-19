
function reslice_masks(varargin)
%% Reslice binary masks to each patient's coregistered SPECT (all patients)
% - Searches for SPECT per patient (prefers r*flippedZ.nii, else any r*BRAIN_SPECT*.nii)
% - Reslices masks from masks to SPECT grid (SPM Coreg:Write, NN interp)
% - Moves r*.nii outputs into each patient's "resliced_masks" folder
%
% Usage:
%   reslice_masks()                                               % Uses default paths
%   reslice_masks(root_pat)                                      % Specify root patient directory only
%   reslice_masks(root_pat, masks_dir)                           % Specify root and masks directory
%   reslice_masks(root_pat, masks_dir, log_file)                 % Specify paths and log file
%   reslice_masks(root_pat, masks_dir, log_file, smp_path)       % Specify all paths including optional SPM path
%
% Requires SPM12 on path.

% Parse input arguments
if nargin >= 1
    root_pat = varargin{1};
else
    root_pat = 'coregistered_DAT';  % Default patient root directory
end

if nargin >= 2
    masks_dir = varargin{2};
else
    masks_dir = './masks';  % Default masks directory
end

if nargin >= 3
    log_file = varargin{3};
else
    log_file = './priv/reslice_mask.log';  % Default log file path
end

if nargin >= 4 && ~isempty(varargin{4})
    smp_path = varargin{4};
    addpath(smp_path);
    fprintf('Added SPM path: %s\n', smp_path);
end

% --- Setup logging ---
[log_dir, ~, ~] = fileparts(log_file);
if ~isempty(log_dir) && ~exist(log_dir, 'dir'), mkdir(log_dir); end
log_fid = fopen(log_file, 'w');
if log_fid == -1
    error('Could not create log file: %s', log_file);
end

% Helper function to log both to console and file
log_msg = @(msg) fprintf_both(log_fid, msg);

log_msg(sprintf('=== Reslice Masks Log - %s ===\n', datestr(now)));
log_msg(sprintf('Root patient directory: %s\n', root_pat));
log_msg(sprintf('Masks directory: %s\n', masks_dir));
log_msg(sprintf('Log file: %s\n\n', log_file));

% ---- Binary masks (use your *_bin files and SN/SLF) ----
mask_names = { ...
  'JHU-SLF-binary.nii', ...
  'fOccipital_bin.nii', ...
  'aCAU_lh_bin.nii','aCAU_rh_bin.nii','aPUT_lh_bin.nii','aPUT_rh_bin.nii', ...
  'pCAU_lh_bin.nii','pCAU_rh_bin.nii','pPUT_lh_bin.nii','pPUT_rh_bin.nii', ...
  'SN_L_binary.nii','SN_R_binary.nii'};

% --- helper: resolve .nii or .nii.gz (unzip if needed) ---
resolveMask = @(basePath) resolve_mask_local(basePath);

% --- SPM init ---
spm('defaults','FMRI'); spm_jobman('initcfg');

% --- list patients ---
D = dir(root_pat);
D = D([D.isdir] & ~ismember({D.name},{'.','..'}));

total_pat = numel(D); done_pat = 0; skipped_pat = 0;
log_msg(sprintf('Found %d patient directories to process\n\n', total_pat));

for s = 1:total_pat
    subj_dir = fullfile(root_pat, D(s).name);

    % --- find SPECT for this subject (prefer r*flippedZ.nii, else r*BRAIN_SPECT*.nii) ---
    F1 = dir(fullfile(subj_dir, 'r*flippedZ.nii'));
    F2 = dir(fullfile(subj_dir, 'r*BRAIN_SPECT*.nii'));
    F = [F1; F2];

    if isempty(F)
        log_msg(sprintf('[%s] No coregistered SPECT found (expected r*flippedZ.nii or r*BRAIN_SPECT*.nii). Skipping.\n', D(s).name));
        skipped_pat = skipped_pat + 1;
        continue;
    end

    % If multiple, pick the most recent
    [~, idx] = max([F.datenum]);
    spect_img = fullfile(F(idx).folder, F(idx).name);

    % ---- build SPM source list (Nx1 column cell with ,1) ----
    src_list = cell(numel(mask_names),1);
    try
        for i = 1:numel(mask_names)
            p = resolveMask(fullfile(masks_dir, mask_names{i}));
            src_list{i,1} = [p ',1'];
        end
    catch ME
        log_msg(sprintf('[%s] Mask resolving failed: %s\n', D(s).name, ME.message));
        skipped_pat = skipped_pat + 1;
        continue;
    end

    % ---- Coregister: WRITE (reslice masks to spect_img grid) ----
    matlabbatch = [];
    matlabbatch{1}.spm.spatial.coreg.write.ref    = { [spect_img ',1'] };
    matlabbatch{1}.spm.spatial.coreg.write.source = src_list;
    matlabbatch{1}.spm.spatial.coreg.write.roptions.interp = 0; % nearest-neighbor for binary
    matlabbatch{1}.spm.spatial.coreg.write.roptions.wrap   = [0 0 0];
    matlabbatch{1}.spm.spatial.coreg.write.roptions.mask   = 0;
    matlabbatch{1}.spm.spatial.coreg.write.roptions.prefix = 'r';

    try
        spm_jobman('run', matlabbatch);
    catch ME
        log_msg(sprintf('[%s] Reslice failed: %s\n', D(s).name, ME.message));
        skipped_pat = skipped_pat + 1;
        continue;
    end

    % ---- Move resliced masks to subject/resliced_masks ----
    dest_dir = fullfile(subj_dir, 'resliced_masks');
    if ~exist(dest_dir,'dir'), mkdir(dest_dir); end

    moved = 0;
    for i = 1:numel(mask_names)
        src_r = fullfile(masks_dir, ['r' mask_names{i}]);   % SPM writes here
        if isfile(src_r)
            [~,nm,~] = fileparts(mask_names{i});            % e.g., aPUT_lh_bin
            dst = fullfile(dest_dir, sprintf('r_%s.nii', nm));
            try
                movefile(src_r, dst, 'f');
                moved = moved + 1;
            catch ME
                log_msg(sprintf('[%s] Could not move %s: %s\n', D(s).name, src_r, ME.message));
            end
        else
            log_msg(sprintf('[%s] Expected resliced not found: %s\n', D(s).name, src_r));
        end
    end

    log_msg(sprintf('[%s] OK → %d masks moved to %s\n', D(s).name, moved, dest_dir));
    done_pat = done_pat + 1;
end

log_msg(sprintf('\nSummary: processed=%d | skipped=%d | total=%d\n', done_pat, skipped_pat, total_pat));
log_msg(sprintf('=== Log completed at %s ===\n', datestr(now)));

% Close log file
fclose(log_fid);
fprintf('Log saved to: %s\n', log_file);

% ===== helper functions (local subfunctions) =====
    function fprintf_both(fid, msg)
        % Print to both console and log file
        fprintf('%s', msg);
        fprintf(fid, '%s', msg);
    end

    function p = resolve_mask_local(p_nifti)
        % If .nii exists, return it; else try .nii.gz and unzip once
        if isfile(p_nifti)
            p = p_nifti; return;
        end
        gz = [p_nifti '.gz'];
        if isfile(gz)
            try
                gunzip(gz);
            catch ME
                error('gunzip failed for %s: %s', gz, ME.message);
            end
            if ~isfile(p_nifti)
                error('After gunzip, missing: %s', p_nifti);
            end
            p = p_nifti; return;
        end
        error('Mask not found: %s (nor %s)', p_nifti, gz);
    end

end
