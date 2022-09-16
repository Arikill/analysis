%% Data reading parameters.
filename = "example_data2.xlsx"; % The path+name of the file goes here.
paradigms = ["10pps", "20pps", "40pps", "60pps", "80pps"]; % Different rates in the file go here; these should be the same as the worksheets in the file.
active_duration = [0.6, 0.4, 0.35, 0.3, 0.3]; % How long does the response to simulus last at each pulse rate? (secs).
rec = WholeCellRecording2(filename, paradigms, active_duration);
%% Filter parameters.
filter_parameters.CutOffFrequency = 150; % The lower this value, the smoother the traces get, but stay above 80 (Hz) for now.
filter_parameters.CutOffFrequency2 = 20;
filter_parameters.FilterOrder = 100;
filter_parameters.PassbandRipple = 0.01;
filter_parameters.StopbandAttenuation = 80;
%% Analysis.
rec = rec.call(filter_parameters);
%% Plotting.
rec = rec.plots();
%% Computing stats.
stats = rec.get_stats();
disp(stats);
%% Writing stats to file.
rec.write_stats_to_file(stats, filename, strcat('Stats', strrep(datestr(now), ':', '-')));
%% Computing meta-stats.
meta_stats = rec.get_meta_stats();
disp(meta_stats);
%% Writing meta-stats to file.
rec.write_meta_stats_to_file(meta_stats, filename, strcat('MetaStats', strrep(datestr(now), ':', '-')));