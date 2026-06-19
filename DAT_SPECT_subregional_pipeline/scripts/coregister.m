function coregister(varargin)
%% coregister_flippedZ_all.m
% Coregister + Reslice all *_flippedZ.nii to the MNI DaT template (SPM12)
%
% Usage:
%   coregister()                                            % Uses default paths
%   coregister(data_root)                                   % Specify data root directory only
%   coregister(data_root, ref_path)                         % Specify data root and reference path
%   coregister(data_root, ref_path, log_file)               % Specify paths and log file
%   coregister(data_root, ref_path, log_file, smp_path)     % Specify all paths including optional SPM path

% Parse input arguments
if nargin >= 1
    data_root = varargin{1};
else
    data_root = 'coregistered_DAT';  % Default data root path
end

if nargin >= 2
    ref_path = varargin{2};
else
    ref_path = './masks/symFPCITtemplate_MNI_norm.nii';  % Default reference template
end

if nargin >= 3
    log_file = varargin{3};
else
    log_file = './priv/coregister.log';  % Default log file path
end

if nargin >= 4 && ~isempty(varargin{4})
    smp_path = varargin{4};
    addpath(smp_path);
    fprintf('Added SPM path: %s\n', smp_path);
end

% --- Setup logging ---
[log_dir, log_name, log_ext] = fileparts(log_file);
if ~isempty(log_dir) && ~exist(log_dir, 'dir')
    try mkdir(log_dir); catch, log_file = [log_name log_ext]; end
end

log_fid = fopen(log_file, 'w');
if log_fid == -1, log_fid = []; end
log_msg = @(msg) fprintf_both(log_fid, msg);

log_msg(sprintf('=== Coregister Log - %s ===\n', datestr(now)));
log_msg(sprintf('Data root: %s\n', data_root));
log_msg(sprintf('Reference: %s\n', ref_path));
log_msg(sprintf('Log file: %s\n\n', log_file));

spm('defaults','FMRI'); 
spm_jobman('initcfg');

% Make sure SPM sees a volume index
ref_img = [ref_path ',1'];

subs = dir(data_root);
subs = subs([subs.isdir] & ~ismember({subs.name},{'.','..'}));
log_msg(sprintf('Found %d subjects to process\n\n', numel(subs)));

for s = 1:numel(subs)
    subj_dir = fullfile(data_root, subs(s).name);

    % find flipped files only
    F = dir(fullfile(subj_dir, '*_flippedZ.nii'));
    if isempty(F)
        log_msg(sprintf('[%s] no *_flippedZ.nii\n', subs(s).name));
        continue;
    end

    for k = 1:numel(F)
        try
            src_path = fullfile(F(k).folder, F(k).name);

            % --- (recommended) reset origin to center-of-mass to help optimizer ---
            V = spm_vol(src_path); Y = spm_read_vols(V);
            [ix,iy,iz] = ind2sub(V.dim, find(Y>0));
            if isempty(ix), com = (V.dim+1)/2; else, com = [mean(ix) mean(iy) mean(iz)]; end
            com_mm = V.mat*[com 1]';
            M = V.mat; M(1:3,4) = M(1:3,4) - com_mm(1:3);
            spm_get_space(src_path, M);

            % --- Coregister: Estimate & Reslice ---
            matlabbatch = [];
            matlabbatch{1}.spm.spatial.coreg.estwrite.ref    = {ref_img};
            matlabbatch{1}.spm.spatial.coreg.estwrite.source = {[src_path ',1']};
            matlabbatch{1}.spm.spatial.coreg.estwrite.other  = {''};

            % estimation options
            matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.cost_fun = 'nmi';
            matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.sep      = [4 2];
            matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.tol      = ...
                [0.02 0.02 0.02  0.001 0.001 0.001  0.01 0.01 0.01  0.001 0.001 0.001];
            matlabbatch{1}.spm.spatial.coreg.estwrite.eoptions.fwhm     = [7 7];

            % reslice options (write r*.nii in template grid)
            matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.interp   = 4;
            matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.wrap     = [0 0 0];
            matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.mask     = 0;
            matlabbatch{1}.spm.spatial.coreg.estwrite.roptions.prefix   = 'r';

            spm_jobman('run', matlabbatch);
            log_msg(sprintf('[%s] OK: %s -> r*.nii\n', subs(s).name, F(k).name));

        catch ME
            log_msg(sprintf('[%s] failed on %s: %s\n', subs(s).name, F(k).name, ME.message));
        end
    end
end

log_msg(sprintf('\nDone. Load template + r*_flippedZ.nii in SPM Check Reg to verify overlap.\n'));
log_msg(sprintf('=== Log completed at %s ===\n', datestr(now)));

% Close log file
if ~isempty(log_fid), fclose(log_fid); fprintf('Log: %s\n', log_file); end

    % Helper function for logging
    function fprintf_both(fid, msg)
        fprintf('%s', msg);
        if ~isempty(fid), fprintf(fid, '%s', msg); end
    end

end  % End of function
