classdef WholeCellRecording2
   properties
       %% Sampling/Acquistion properties.
       Fs % Sampling Frequency of acquisition (Hz).
       response_samples % How long the response lasts in a sampling domain (samples).

       %% Stimulus properties.
       rate
       npulses
       
       %% Cell properties.
       Cm % Membrane Capacitance (F).
       Rin % Input Resistance of the cell (Ohms).
       Er % Resting Potential of the cell: Steady State Potential at 0nA current clamp(V).
       Ee % Excitatory Reversal Potential: potential at which excitation is reversed and appears as hyperpolarization (V).
       Ei % Inhibitory Reversal Potential: potential at which inhibition is reversed and appears as depolarization (V).
       Et % Threshold Potential: potential at which an action potential is triggered or supra-threshold active currents are triggered (V).
       Eact % Activation Potential: potential at which subthreshold active currents are triggered (V).
       Ess % Steady State Potential: settled potential at a given current clamp when no stimulus is presented (V).
       xalpha % Alpha Multiplier: multiplier on the active current estimate (dimensionless).
       xbeta % Beta Multiplier: multiplier on the compensator for the active current (dimensionless).
       sps % spikes for stimulus repetition (spikes/stim.rep.).
       Eref % Reference Potential: potential used as reference to measure de- and hyperpolarizations (V).
       
       %% filter properties
       CutOffFrequency % Frequency in the signal where the noise starts to dominate the signal (Hz). 
       FilterOrder % The number of previous timesteps that need to be used in filtering (dimensionless).
       PassbandRipple % The amplitude of ripples in frequencies of the passband (dB).
       StopbandAttenuation % The attentuation of noise (dB).
       
       %% analysis properties
       stimulus
       time % times(secs) extracted from recorded data.
       Vm % Transmembrane Potential (V) recorded at Fs.
       Im % Transmembrane current (A) computed as Cm*(dVm/dt).
       Iinj % Injected Current (A).
       Ileak % Leakage current (A) of the cell, computed as (1/Rin)*(Vm - Er).
       alpha % Active conductance constant (S/V); Estimated using algorithm from Alluri, 2021. 
       beta % Active conductance constant (S); Estimated using algorithm from Alluri, 2021.
       Iactive % Active current (A) computed using active conductance terms. Alluri, 2021.
       ge % Excitatory conductance (S) estimated using alogrithm from Alluri, 2016.
       gi % Inhibitory conductance (S) estimated using alogrith from Alluri, 2016.
       Ie % Excitatory currents (A) at various current clamps computed as ge*(Vm - Ee).
       Ii % Inhibitory currents (A) at various current clamps computed as gi*(Vm - Ei).
       depolarizations % Vm > Er at every time point (V).
       hyperpolarizations % Vm < Er at every time point (V).
       excitation % ge > 0. Biological data is noisy, excitation variable is free of aberrent negative values of ge.
       inhibition % gi > 0. Biological data is noisy, inhibition variable is free of aberrent negative values of gi after non-linear filtering using alpha and beta.
       paradigm % paradigm (string) is different types of stimuli, for pulse rate 5pps, 10pps, 60pps, etc., or for duration 20ms, 40ms, 160ms, etc.
       filename % filename (string) is the name of the file containing the current clamp data along with various parameters for cell and membrane potential constants.
       response_durations

       %% stats
        ge_net
        gi_net
        ge_max
        gi_max
        ge_mean
        gi_mean
        depolarizations_max
        hyperpolarizations_max
        depolarizations_mean
        hyperpolarizations_mean
   end
   properties(Access=private)
       %% fig properties
       fig
   end
   %% Methods
   methods(Access=private)
       function app = readXLSXdata(app)
           [m, n] = size(app);
           for i = 1: 1: m
               for j = 1: 1: n
                    data = readtable(app(i, j).filename, 'Sheet', app(i, j).paradigm, 'ReadVariableNames', 1, 'VariableNamingRule', 'preserve');
                    try
                        app(i, j).time = data.times;
                        data.times = [];
                    catch
                        error(strcat('times array was not found! Check ', app(i, j).filename, ' and ', app(i, j).paradigm, ' !'));
                    end
                    try
                        app(i, j).stimulus = data.stimulus;
                        data.stimulus = [];
                    catch
                        app(i, j).stimulus = zeros(size(app(i, j).time));
                    end
                    app(i, j).Vm = table2array(data).*1e-3;
                    app(i, j).Fs = 1/(app(i, j).time(2, 1) - app(i, j).time(1, 1));
                    app(i, j).response_samples = floor(app(i, j).Fs*app(i, j).response_durations(i));
                    samples = size(app(i, j).time, 1);
                    if app(i, j).response_samples > samples-1
                       app(i, j).response_samples = samples-1;
                    end
               end
           end
       end

       function app = adjust_membrane_potential_with_steady_state(app)
           [m, n] = size(app);
           for i = 1: 1: m
               for j = 1: 1: n
                   app(i, j).Iinj = (1./app(i, j).Rin).*(app(i, j).Ess - app(i, j).Er);
                   app(i, j).Vm = app(i, j).Vm - app(i, j).Vm(1, :) + app(i, j).Ess;
               end
           end
       end

       function app = readXLSXparameters(app)
           [m, n] = size(app);
           for i = 1: 1: m
               for j = 1: 1: n
                    parameters = readtable(app(i, j).filename, 'Sheet', strcat("parameters_", app(i, j).paradigm));
                    app(i, j).Iinj = parameters.Iinj' + zeros(size(app(i, j).Vm));
                    app(i, j).Cm = parameters.Cm' + zeros(size(app(i, j).Vm));
                    app(i, j).Rin = parameters.Rin' + zeros(size(app(i, j).Vm));
                    app(i, j).Er = parameters.Er' + zeros(size(app(i, j).Vm));
                    app(i, j).Ee = parameters.Ee' + zeros(size(app(i, j).Vm));
                    app(i, j).Ei = parameters.Ei' + zeros(size(app(i, j).Vm));
                    app(i, j).Et = parameters.Et' + zeros(size(app(i, j).Vm));
                    app(i, j).Eact = parameters.Eact' + zeros(size(app(i, j).Vm));
                    app(i, j).Ess = parameters.Ess' + zeros(size(app(i, j).Vm));
                    app(i, j).xalpha = parameters.xalpha' + zeros(size(app(i, j).Vm));
                    app(i, j).xbeta = parameters.xbeta' + zeros(size(app(i, j).Vm));
                    app(i, j).sps = parameters.sps' + zeros(size(app(i, j).Vm));
                    app(i, j).Eref = parameters.Eref' + zeros(size(app(i, j).Vm));
                    app(i, j).rate = parameters.rate;
                    app(i, j).npulses = parameters.npulses;
               end
           end
       end

       function app = build_arrays(app)
           [m, n] = size(app);
           for i = 1: 1: m
               for j = 1: 1: n
                    samples = size(app(i, j).Vm, 2);
                    app(i, j).Iactive = zeros(size(app(i, j).Vm));
                    app(i, j).ge = zeros(samples, 1);
                    app(i, j).gi = zeros(samples, 1);
                    app(i, j).Ie = zeros(size(app(i, j).Vm));
                    app(i, j).Ii = zeros(size(app(i, j).Vm));
                    app(i, j).ge_net = zeros(samples, 1);
                    app(i, j).gi_net = zeros(samples, 1);
                    app(i, j).depolarizations = zeros(samples, 1);
                    app(i, j).hyperpolarizations = zeros(samples, 1);
                    app(i, j).excitation = zeros(samples, 1);
                    app(i, j).inhibition = zeros(samples, 1);
                    app(i, j).ge_max = 0;
                    app(i, j).gi_max = 0;
                    app(i, j).ge_mean = 0;
                    app(i, j).gi_mean = 0;
                    app(i, j).depolarizations_max = 0;
                    app(i, j).hyperpolarizations_max = 0;
                    app(i, j).depolarizations_mean = 0;
                    app(i, j).hyperpolarizations_mean = 0;
               end
           end
       end
   end
   methods
       %% Constructor
       function app = WholeCellRecording2(filename, paradigms, response_durations)
            if nargin > 0
                tStart = tic;
                %% Input format check
                if ~isa(filename, 'string')
                    error('filename must be a string'); 
                end
                if ~isa(paradigms, 'string')
                    error('conditions (rates/durations) must be strings'); 
                end
                if ~isa(response_durations, 'double')
                    error('responseDurations must be doubles');
                end
                if ~isequal(size(paradigms), size(response_durations))
                    error('Dimensions of conditions and responseDurations must match.');
                end
                [m, n] = size(response_durations);
                app(m, n) = app;
                for i = 1: 1: m
                    for j = 1: 1: n
                        app(i, j).filename = filename;
                        app(i, j).paradigm = paradigms(i, j);
                        app(i, j).response_durations = response_durations(i, j);
                    end
                end
                %% Reading worksheets from excel files.
                app = app.readXLSXdata();
                app = app.build_arrays();
                app = app.readXLSXparameters();
                app = app.adjust_membrane_potential_with_steady_state();
                fprintf('[%d secs] Read %s\n', toc(tStart), filename);
            end
       end
       function app = zero_phase_filter_Vm(app, filter_parameters)
           tStart = tic;
           [m, n] = size(app);
           for i = 1: 1: m
               for j = 1: 1: n
                   Fnorm = filter_parameters.CutOffFrequency/(app(i, j).Fs/2);
                   lpFilt = designfilt('lowpassiir', ...
                                'PassbandFrequency', Fnorm, ...
                                'FilterOrder', filter_parameters.FilterOrder, ...
                                'PassbandRipple', filter_parameters.PassbandRipple, ...
                                'StopbandAttenuation', filter_parameters.StopbandAttenuation);
                   v = cat(1, ones(size(app(i, j).Vm)).*(app(i, j).Vm(1, :)), app(i, j).Vm);
                   v = cat(1, v, ones(size(app(i, j).Vm)).*(app(i, j).Vm(end, :)));
                   vn = v - v(1, :);
                   Vmf = filtfilt(lpFilt, vn);
                   app(i, j).Vm = Vmf(size(app(i, j).Vm, 1)+1:end-size(app(i, j).Vm, 1), :) + app(i, j).Vm(1, :);
               end
           end
           fprintf('[%d secs] Zero phase filtering Vm \n', toc(tStart));
       end

       function app = compute_active_conductances(app)
           tStart = tic;
           [m, n] = size(app);
           for i = 1: 1: m
               for j = 1: 1: n
                   app(i, j).alpha = ((1./app(i, j).Rin)./(2.*(app(i, j).Eact-app(i, j).Ess)));
                   app(i, j).beta = app(i, j).alpha.*(app(i, j).Et - app(i, j).Ess);
                   app(i, j).alpha = app(i, j).alpha.*app(i, j).xalpha;
                   app(i, j).beta = app(i, j).beta.*app(i, j).xbeta;
               end
           end
           fprintf('[%d secs] Computed active conductances (constants)\n', toc(tStart));
       end

       function app = compute_active_currents(app)
           tStart = tic;
           [m, n] = size(app);
           for i = 1: 1: m
               for j = 1: 1: n
                  app(i, j).Iactive = (app(i, j).alpha.*(app(i, j).Vm-app(i, j).Et).*(app(i, j).Vm-app(i, j).Er)) ...
                          + (app(i, j).beta.*(app(i, j).Vm-app(i, j).Er));
               end
           end
           fprintf('[%d secs] Computed active currents\n', toc(tStart));
       end

       function app = compute_leakage_currents(app)
           tStart = tic;
           [m, n] = size(app);
           for i = 1: 1: m
               for j = 1: 1: n
                   app(i, j).Ileak = (1./app(i, j).Rin).*(app(i, j).Vm-app(i, j).Er);
               end
           end
           fprintf('[%d secs] Computed leakage currents\n', toc(tStart));
       end

       function app = compute_membrane_currents(app)
           tStart=tic;
           [m, n] = size(app);
           for i = 1: 1: m
               for j = 1: 1: n
                    Vm_appended = cat(1, app(i, j).Vm(1, :), app(i, j).Vm, app(i, j).Vm(end, :));
                    dVmdt = diff(Vm_appended);
                    app(i, j).Im = app(i, j).Cm.*dVmdt(1:end-1, :).*(app(i, j).Fs);
               end
           end
           fprintf('[%d secs] Computed membrane currents\n', toc(tStart));
       end

       function app = zero_phase_filter_Im(app, filter_parameters)
            tStart = tic;
            [m, n] = size(app);
            for i = 1: 1: m
                for j = 1: 1: n
                    Fnorm = filter_parameters.CutOffFrequency/(app(i, j).Fs/2);
                    lpFilt = designfilt('lowpassiir', ...
                                'PassbandFrequency', Fnorm, ...
                                'FilterOrder', filter_parameters.FilterOrder, ...
                                'PassbandRipple', filter_parameters.PassbandRipple, ...
                                'StopbandAttenuation', filter_parameters.StopbandAttenuation);
                    I = cat(1, ones(size(app(i, j).Im)).*(app(i, j).Im(1, :)), app(i, j).Im);
                    I = cat(1, I, ones(size(app(i, j).Im)).*(app(i, j).Im(end, :)));
                    in = I - I(1, :);
                    Imf = filtfilt(lpFilt, in);
                    app(i, j).Im = Imf(size(app(i, j).Im, 1)+1:end-size(app(i, j).Im, 1), :) + app(i, j).Im(1, :);
                end
            end
            fprintf('[%d secs] Zero phase filtering Im \n', toc(tStart));
       end

       function app = compute_passive_conductances(app)
           tStart = tic;
           [m, n] = size(app);
           for i = 1: 1: m
               for j = 1: 1: n
                   samples = size(app(i, j).Vm, 1);
                   A = zeros(2, 2, samples);
                   B = zeros(2, 1, samples);
                   A(1, 1, :) = sum((app(i, j).Vm - app(i, j).Ee).^2, 2);
                   A(1, 2, :) = sum((app(i, j).Vm - app(i, j).Ee).*(app(i, j).Vm - app(i, j).Ei), 2);
                   A(2, 1, :) = A(1, 2, :);
                   A(2, 2, :) = sum((app(i, j).Vm - app(i, j).Ei).^2, 2);
                   C = app(i, j).Im - app(i, j).Iinj - app(i, j).Iactive + app(i, j).Ileak;
                   B(1, 1, :) = -sum(C.*(app(i, j).Vm - app(i, j).Ee), 2);
                   B(2, 1, :) = -sum(C.*(app(i, j).Vm - app(i, j).Ei), 2);
                   G = pagemtimes(pageinv(A), B);
                   app(i, j).ge = reshape(G(1, 1, :), [samples, 1]);
                   app(i, j).gi = reshape(G(2, 1, :), [samples, 1]);
               end
           end
           fprintf('[%d secs] Computed passive conductances\n', toc(tStart));
       end

       function app = compute_stats(app)
           tStart = tic;
           [m, n] = size(app);
           for i = 1: 1: m
               for j = 1: 1: n
                   del_Vm = app(i, j).Vm - app(i, j).Eref;
               end
           end
           fprintf('[%d secs] Computed Stats\n', toc(tStart));
       end

       function app = plots(app)
            tStart = tic;
            app(1).fig = figure('Name', strcat(app(1).filename, ' Reconstructions'));
            tiledlayout(6, length(app));
            ax = cell(6, length(app));
            for m = 1: 1: 6
               for k = 1: 1: length(app)
                   ax{m, k} = nexttile;
                   if m == 1
                      plot(app(k).time, app(k).Vm);
                      if k == 1
                        ylabel('Vm (V)');
                      end
                      title(strcat(app(k).condition));
                   elseif m == 2
                      plot(app(k).time, app(k).Iactive);
                      if k == 1
                        ylabel('Iactive (A)');
                      end
                   elseif m == 3
                      plot(app(k).time, app(k).Ileak);
                      if k == 1
                        ylabel('Ileak (A)');
                      end
                   elseif m == 4
                      plot(app(k).time, app(k).Im);
                      if k == 1
                        ylabel('Im (A)');
                      end
                   elseif m == 5
                       plot(app(k).time, app(k).ge, 'r', app(k).time, app(k).gi, 'b');
                       if k == 1
                         ylabel('G (S)');
                       end
                       xlabel('Time (sec)');
                   elseif m == 6
                       plot(app(k).time, app(k).Ie(:, 1), 'r', app(k).time, -1.*app(k).Ii(:, 1), 'b');
                       if k == 1
                           ylabel('I (A)');
                       end
                       xlabel('Time (sec)');
                   end
               end
               linkaxes([ax{m, :}], 'xy');
            end
            fprintf('[%d secs] Plotting data\n', toc(tStart));
       end
       function app = dynamics_plots(app)
            tStart = tic;
            app(1).fig = figure('Name', strcat(app(1).filename, ' Dynamics plots'));
            tiledlayout(4, length(app));
            ax = cell(4, length(app));
            for m = 1: 1: 4
                for k = 1: 1: length(app)
                    ax{m, k} = nexttile;
                    if m == 1
                        plot(app(k).Vm, app(k).Im);
                        xlabel('Vm (V)');
                        if k == 1
                            ylabel('Im (A)');
                        end
                        title(strcat(app(k).condition'));
                    elseif m == 2
                        plot(app(k).Vm, app(k).Iactive);
                        xlabel('Vm (V)');
                        if k == 1
                            ylabel('Iactive (A)');
                        end
                    elseif m == 3
                        plot(app(k).Vm, app(k).Ileak);
                        xlabel('Vm (V)');
                        if k == 1
                            ylabel('Ileak (A)');
                        end
                    elseif m == 4
                        plot(app(k).Im, app(k).Iactive);
                        xlabel('Im (A)');
                        if k == 1
                            ylabel('Iactive (A)');
                        end
                    end
                end
            end
            fprintf('[%d secs] Dynamics Plotting data\n', toc(tStart));
       end
       function [app, stats] = generate_stats(app)
           tStart = tic;
           net_conductances = zeros(length(app), 2);
           mean_conductances = zeros(length(app), 2);
           mean_polarizations = zeros(length(app), 2);
           mean_active_current = zeros(length(app), 1);
           spikes_per_rep = zeros(length(app), 1);
           pulse_rates = strings([length(app), 1]);
           data_count = zeros(length(app), 1);
           app(1).fig = figure('Name', strcat(app(1).filename, ' Stats'));
           set(app(1).fig,'defaultAxesColorOrder',[[0.5 0.5 0]; [0 0 0]]);
           tiledlayout(2, 1);
           ax = cell(2, 1);
           for k = 1: 1: length(app)
               del_Vm = (app(k).Vm(:, 1) - app(k).Eref(1));
               app(k).depolarizations = del_Vm(:, 1).*(del_Vm(:, 1)>0);
               app(k).hyperpolarizations = del_Vm(:, 1).*(del_Vm(:, 1)<0);
               app(k).excitation = app(k).ge.*(app(k).ge>0);
               app(k).inhibition = app(k).gi.*(app(k).gi>0);
               resultant_conductance = app(k).excitation(1:app(k).response_samples) - app(k).inhibition(1:app(k).response_samples);
               net_conductances(k, 1) = mean(resultant_conductance.*(resultant_conductance>0));
               net_conductances(k, 2) = mean(resultant_conductance.*(resultant_conductance<0));
               mean_conductances(k, 1) = mean(app(k).excitation(1:app(k).response_samples));
               mean_conductances(k, 2) = -1.*mean(app(k).inhibition(1:app(k).response_samples));
               mean_polarizations(k, 1) = mean(app(k).depolarizations(1:app(k).response_samples));
               mean_polarizations(k, 2) = mean(app(k).hyperpolarizations(1:app(k).response_samples));
               mean_active_current(k, 1) = mean(app(k).Iactive(1:app(k).response_samples, 1));
               spikes_per_rep(k, 1) = app(k).sps(1);
               pulse_rates(k, 1) = app(k).condition;
               data_count(k, 1) = k;
%                fprintf('mean depolarization %d, mean hyperpolarization %d, mean excitation %d, mean inhibition %d\n', mean(app(k).depolarizations), mean(app(k).hyperpolarizations), mean(app(k).excitation), mean(app(k).inhibition));
           end
           ax{1, 1} = nexttile;
           yyaxis left;
           mean_plt = bar(data_count, mean_conductances, 0.3, 'stacked', 'FaceColor', 'flat');
           hold on;
           net_plt = bar(data_count, net_conductances, 0.5, 'stacked', 'FaceColor', 'flat');
           hold off;
           ylabel('Mean Conductance (S)');
           xlabel('Pulse Rate');
           for k = 1: 1: length(app)
               mean_plt(1).CData(k, :) = [1, 0, 0];
               mean_plt(2).CData(k, :) = [0, 0, 1];
               net_plt(1).CData(k, :) = [1, 0, 0];
               net_plt(2).CData(k, :) = [0, 0, 1];
           end
           y1max = max(mean_conductances, [], 'all');
           y1max = y1max+0.1*y1max;
           if y1max == 0
               ylim([0, 1]);
           else
               ylim([-y1max, y1max]);
           end
           y2max = max(spikes_per_rep, [], 'all');
           y2max = y2max+0.1*y2max;
           yyaxis right;
           plot(data_count, spikes_per_rep, '-ok');
           ylabel('Spikes per stim. rep. (SPS)');
           if y2max == 0
               ylim([0, 1]);
           else
               ylim([-y2max, y2max]);
           end
           set(ax{1, 1},'xticklabel',pulse_rates);
           ax{2, 1} = nexttile;
           yyaxis left;
           mean_plt = bar(data_count, mean_polarizations, 'stacked', 'FaceColor', 'flat');
           ylabel('Mean Polarizaions (V)');
           xlabel('Pulse Rate');
           for k = 1: 1: length(app)
               mean_plt(1).CData(k, :) = [1, 0, 0];
               mean_plt(2).CData(k, :) = [0, 0, 1];
           end
           y1max = max(mean_polarizations, [], 'all');
           y1max = y1max+0.1*y1max;
           if y1max == 0
               ylim([0, 1]);
           else
               ylim([-y1max, y1max]);
           end
           y2max = max(spikes_per_rep, [], 'all');
           y2max = y2max+0.1*y2max;
           yyaxis right;
           plot(data_count, spikes_per_rep, '-ok');
           ylabel('Spikes per stim. rep. (SPS)');
           if y2max == 0
               ylim([0, 1]);
           else
               ylim([-y2max, y2max]);
           end
           set(ax{2, 1},'xticklabel',pulse_rates);
           fprintf('[%d secs] Plotting stats\n', toc(tStart));
           stats = table(pulse_rates, spikes_per_rep, mean_polarizations, mean_conductances, net_conductances, mean_active_current);
       end
   end
end