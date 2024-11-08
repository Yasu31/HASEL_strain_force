% Script to plot Force vs. Strain_mean from processed data files

% Clear workspace and figures
clear;
close all;

files = dir('processed_*.txt');

% Check if any files are found
if isempty(files)
    error('No files matching "processed_*.txt" were found in the specified directory.');
end

% Create a figure for plotting
figure;
hold on;

% Loop over each file
for k = 1:length(files)
    % Get the full file name
    filename = fullfile(files(k).folder, files(k).name);
    
    legend_text = extractLabelFromFilename(filename);
    [force, strain] = loadFile(filename);
    % Plot the data with the legend entry
    plot(strain, force, 'DisplayName', legend_text);
end

% Configure the plot
hold off;
grid on;
xlabel('Strain Mean [mm]');
ylabel('Force [N]');
title('Force vs. Strain Mean for Processed Data Files');
legend('show', 'Location', 'best');

function [Force, Strain] = loadFile(filename)
% Load the force-strain (mean strain) data from a file
% Read the data table from the file
T = readtable(filename, 'Delimiter', ',', 'ReadVariableNames', true);
% Get the variable names from the table
colnames = T.Properties.VariableNames;

% Find the columns for 'Force' and 'Strain_mean'
Force_col = find(contains(colnames, 'Force'));
Strain_mean_col = find(contains(colnames, 'Strain_mean'));

% Check if the required columns are found
if isempty(Force_col) || isempty(Strain_mean_col)
    error('Cannot find "Force" or "Strain_mean" columns in file %s', filename);
end
% Extract the data for Force and Strain_mean
Force = T{:, Force_col};
Strain = T{:, Strain_mean_col};
end

function label = extractLabelFromFilename(filename)
% Extract the legend text from the filename
% We want the text between 'processed_' and '_05Hz'
% e.g. processed_1p23A_05Hz_7kV_Rampedsquare_30kVs_2024_11_06_1902.txt -> 1p23A
[~, name, ~] = fileparts(filename);
start_str = 'processed_';
end_str = '_05Hz';
idx1 = strfind(name, start_str);
idx2 = strfind(name, end_str);
if ~isempty(idx1) && ~isempty(idx2)
    % Calculate indices for extracting the substring
    idx_start = idx1 + length(start_str);
    idx_end = idx2 - 1;
    % Extract the legend text
    label = name(idx_start:idx_end);
else
    disp(['Warning: Could not extract label from filename: ', filename]);
    label = name;
end
end
