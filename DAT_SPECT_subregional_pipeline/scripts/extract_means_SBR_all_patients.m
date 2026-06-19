function extract_means_SBR_all_patients(varargin)
%% Extract mean counts per ROI + compute SBR using SLF as reference, all patients
% - Requires: resliced binary masks in <patient>\resliced_masks\ from prior step
% - Writes Excel with real formulas for SBR columns
% - SPM12 may be on path
%
% Usage:
%   extract_means_SBR_all_patients()                                    % Uses default paths
%   extract_means_SBR_all_patients(root_pat)                           % Specify root patient directory only
%   extract_means_SBR_all_patients(root_pat, out_csv)                 % Specify root and output CSV file
%   extract_means_SBR_all_patients(root_pat, out_xlsx, log_file)      % Specify paths and log file
%   extract_means_SBR_all_patients(root_pat, out_xlsx, log_file, spm_path) % Specify all paths including optional SPM path

% Parse input arguments
if nargin >= 1
    root_pat = varargin{1};
else
    root_pat = 'coregistered_DAT';  % Default patient root directory
end

if nargin >= 2
    out_csv = varargin{2};
else
    out_csv = fullfile(root_pat, 'SBR_SLF.csv');  % Default output CSV file
end

if nargin >= 3
    log_file = varargin{3};
else
    log_file = './priv/extract_SBR.log';  % Default log file path
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

log_msg(sprintf('=== Extract SBR Means Log - %s ===\n', datestr(now)));
log_msg(sprintf('Root patient directory: %s\n', root_pat));
log_msg(sprintf('Output CSV file: %s\n', out_csv));
log_msg(sprintf('Log file: %s\n\n', log_file));

% ---- mask filenames expected INSIDE each subject's "resliced_masks" ----
% (exactly as created by the previous reslicing script)
roi_masks = { ...
    'r_aCAU_lh_bin.nii', 'r_aCAU_rh_bin.nii', ...
    'r_aPUT_lh_bin.nii', 'r_aPUT_rh_bin.nii', ...
    'r_pCAU_lh_bin.nii', 'r_pCAU_rh_bin.nii', ...
    'r_pPUT_lh_bin.nii', 'r_pPUT_rh_bin.nii', ...
    'r_SN_L_binary.nii', 'r_SN_R_binary.nii'};

% reference & (optional) occipital
ref_mask  = 'r_JHU-SLF-binary.nii';     % <-- SBR reference
occ_mask  = 'r_fOccipital_bin.nii';     % optional: mean will be reported

% ---- discover subjects ----
D = dir(root_pat);
D = D([D.isdir] & ~ismember({D.name},{'.','..'}));

% ---- headers for Excel ----
headers = [{'SubjectID','Mean_SLF','Mean_Occ'}, ...
    strcat('Mean_', erase(roi_masks, {'.nii','r_'})), ...
    strcat('SBR_',  erase(roi_masks, {'.nii','r_'}))];

rows = {};  % will build a cell array row-by-row

for s = 1:numel(D)
    subj_dir = fullfile(root_pat, D(s).name);
    mdir = fullfile(subj_dir, 'resliced_masks');

    % Find SPECT and validate directories
    F = [dir(fullfile(subj_dir,'r*flippedZ.nii')); dir(fullfile(subj_dir,'r*BRAIN_SPECT*.nii'))];
    if isempty(F) || ~exist(mdir,'dir')
        log_msg(sprintf('[%s] Missing SPECT or resliced_masks folder. Skipping.\n', D(s).name));
        continue;
    end
    
    [~,idx] = max([F.datenum]);
    spect_img = fullfile(F(idx).folder, F(idx).name);

    % Read SPECT volume
    try
        Ys = spm_read_vols(spm_vol(spect_img));
    catch ME
        log_msg(sprintf('[%s] Failed reading SPECT: %s\n', D(s).name, ME.message));
        continue;
    end

    % Extract means and calculate SBR
    meanSLF = mean_in_mask(Ys, fullfile(mdir, ref_mask));
    meanOcc = mean_in_mask(Ys, fullfile(mdir, occ_mask));
    roi_means = arrayfun(@(i) mean_in_mask(Ys, fullfile(mdir, roi_masks{i})), 1:numel(roi_masks));
    roi_sbr = (roi_means - meanSLF) / meanSLF;  % SBR = (ROI - SLF) / SLF
    
    % build one row (subject id + means + calculated SBR values)
    row = [{D(s).name}, {meanSLF}, {meanOcc}, num2cell(roi_means), num2cell(roi_sbr)];
    rows(end+1,1:numel(row)) = row; %#ok<AGROW>
    log_msg(sprintf('[%s] OK - extracted means and calculated SBR for %d ROIs\n', D(s).name, numel(roi_masks)));
end

log_msg(sprintf('\nProcessed %d subjects successfully\n', size(rows,1)));

if isempty(rows)
    error('No subjects processed. Make sure resliced_masks exist and filenames match.');
end

% ---- Prepare data for CSV output ----
nRows = size(rows,1);
C = cell(nRows+1, numel(headers));
C(1,:) = headers;   % header row
C(2:end,:) = rows;  % data rows

% Write to CSV
try writecell(C, out_csv); catch, write_csv_manual(C, out_csv); end
log_msg(sprintf('\nSaved CSV: %s\nSBR = (ROI - SLF) / SLF\n', out_csv));
log_msg(sprintf('=== Log completed at %s ===\n', datestr(now)));

% Close log file
if ~isempty(log_fid), fclose(log_fid); fprintf('Log: %s\n', log_file); end

% ---------- helpers ----------
    function fprintf_both(fid, msg)
        fprintf('%s', msg);
        if ~isempty(fid), fprintf(fid, '%s', msg); end
    end

    function m = mean_in_mask(Ys, mask_path)
% Return mean(Ys(mask==1)); NaN if mask missing or empty
    if ~isfile(mask_path)
        m = NaN; return;
    end
    Vm = spm_vol(mask_path);
    Ym = spm_read_vols(Vm);
    idx = (Ym > 0.5) & isfinite(Ys);
    if ~any(idx(:))
        m = NaN;
    else
        m = mean(Ys(idx));
    end
    end

    function write_csv_manual(C, filename)
    fid = fopen(filename, 'w'); if fid == -1, error('Cannot write: %s', filename); end
    for i = 1:size(C,1)
        for j = 1:size(C,2)
            if j > 1, fprintf(fid, ','); end
            val = C{i,j};
            if ischar(val) || isstring(val)
                fprintf(fid, '"%s"', strrep(char(val), '"', '""'));
            elseif isnumeric(val) && ~isnan(val)
                fprintf(fid, '%.6f', val);
            else
                fprintf(fid, 'NaN');
            end
        end
        fprintf(fid, '\n');
    end
    fclose(fid);
    end

end
