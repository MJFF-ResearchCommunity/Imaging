function flip_nii(varargin)
%% flip_all_ppmi_Z.m
% Flip all .nii images along the Z-axis for all subject folders in PPMI_CO
% Creates new files with suffix "_flippedZ.nii"
%
% Usage:
%   flip_nii()                                   % Uses default paths
%   flip_nii(root_dir)                           % Specify root directory only
%   flip_nii(root_dir, log_file)                 % Specify root directory and log file
%   flip_nii(root_dir, log_file, smp_path)       % Specify all paths including optional SPM path

% Parse input arguments
if nargin >= 1
    root_dir = varargin{1};
else
    root_dir = 'coregistered_DAT';  % Default path
end

if nargin >= 2
    log_file = varargin{2};
else
    log_file = './priv/flip_nii.log';  % Default log file path
end

if nargin >= 3 && ~isempty(varargin{3})
    smp_path = varargin{3};
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

log_msg(sprintf('=== Flip NIfTI Log - %s ===\n', datestr(now)));
log_msg(sprintf('Root directory: %s\n', root_dir));
log_msg(sprintf('Log file: %s\n\n', log_file));

% Get list of subject folders
d = dir(root_dir);
sub_folders = d([d.isdir] & ~ismember({d.name},{'.','..'}));
log_msg(sprintf('Found %d subject folders to process\n\n', numel(sub_folders)));

for s = 1:numel(sub_folders)
    subj_path = fullfile(root_dir, sub_folders(s).name);

    % Find all NIfTI files in this folder
    nii_files = dir(fullfile(subj_path, '*.nii'));

    for f = 1:numel(nii_files)
        file_path = fullfile(nii_files(f).folder, nii_files(f).name);

        % Skip if it's already flipped
        if contains(nii_files(f).name, 'flippedZ', 'IgnoreCase', true)
            log_msg(sprintf('Skipping already flipped: %s\n', file_path));
            continue;
        end

        % Load and flip
        V = spm_vol(file_path);
        Y = spm_read_vols(V);
        Y = flip(Y, 3);  % flip along Z

        % Create output name
        [folder, name, ext] = fileparts(file_path);
        V.fname = fullfile(folder, [name '_flippedZ' ext]);

        % Save
        spm_write_vol(V, Y);
        log_msg(sprintf('Flipped: %s -> %s\n', file_path, V.fname));
    end
end

log_msg(sprintf('\nDone flipping all NIfTI images along Z-axis.\n'));
log_msg(sprintf('=== Log completed at %s ===\n', datestr(now)));

% Close log file
if ~isempty(log_fid), fclose(log_fid); fprintf('Log: %s\n', log_file); end

    % Helper function for logging
    function fprintf_both(fid, msg)
        fprintf('%s', msg);
        if ~isempty(fid), fprintf(fid, '%s', msg); end
    end

end
