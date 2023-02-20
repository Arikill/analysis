classdef WholeCellRecordingV2
    properties
        %% Acquisition:
        fs

        %% Database:
        filename
        paradigm
        response_duration
        response_samples

        %% Stimulus:
        rate
        npulses

        %% Recording:
        times
        stimulus
        membrane_potential
        injected_current

        %% Cell:
        membrane_capacitance
        input_resistance
        resting_potential
        excitatory_reversal_potential 
        inhibitory_reversal_potential
        threshold_potential
        activation_potential
        steady_state_potential
        alpha_multiplier
        beta_multiplier
        spikes_per_stimulus
        reference_potential

        %% Analysis:
        membrane_current
        leakage_current
        alpha
        beta
        activation_current
        excitatory_conductance
        inhibitory_conductance
        excitatory_current
        inhibitory_current
        depolarizations
        hyperpolarizations

        %% Filters
        membrane_potential_filters
        membrane_current_filters
        firdifferentiator
        firlowpass

        %% Stats
    end

    methods(Access=public)
        %% Datastructure building methods
        function app = WholeCellRecordingV2(filename, paradigms, response_durations, membrane_potential_filter_parameters, membrane_current_filter_parameters)
            if nargin > 0
                [m, n] = size(paradigms);
                app(m, n) = app;
                for i = 1: m
                    for j = 1: n
                        app(i, j).filename = filename;
                        app(i, j).paradigm = paradigms(i, j);
                        app(i, j).response_duration = response_durations(i, j);
                    end
                end
                app = app.read_data();
                app = app.read_parameters();
                app = app.build_membrane_potential_filters(membrane_potential_filter_parameters);
                app = app.build_membrane_current_filters(membrane_current_filter_parameters);
            end
        end

        function app = read_data(app)
            [m, n] = size(app);
            for i = 1: m
                for j = 1: n
                    data = readtable(app(i, j).filename, 'Sheet', app(i, j).paradigm, 'ReadVariableNames', 1, 'VariableNamingRule', 'preserve');
                    try
                        app(i, j).times = data.times;
                        app(i, j).fs = 1/(app(i, j).times(2, 1) - app(i, j).times(1, 1));
                        data.times = [];
                    catch
                        error(strcat('times array was not found in ', app(i, j).paradigm, '!'));
                    end
                    try
                        app(i, j).stimulus = data.stimulus;
                        data.stimulus = [];
                    catch
                        warning(strcat('stimulus array was not found in ', app(i, j).paradigm, '!'));
                        app(i, j).stimulus = [];
                    end
                    try
                        app(i, j).membrane_potential = table2array(data).*1e-3;
                    catch
                        error(strcat('membrane potentials was not found in ', app(i, j).paradigm, '!'));
                    end
                    app(i, j).response_samples = app(i, j).fs * app(i, j).response_duration;
                    if app(i, j).response_samples > size(app(i, j).membrane_potential, 1)
                        app(i, j).response_samples = size(app(i, j).membrane_potential, 1);
                    end
                end
            end
        end

        function app = read_parameters(app)
            [m, n] = size(app);
            for i = 1: m
                for j = 1: n
                    parameters = readtable(app(i, j).filename, 'Sheet', strcat('parameters_', app(i, j).paradigm));
                    app(i, j).injected_current = parameters.Iinj' + zeros(size(app(i, j).membrane_potential));
                    app(i, j).membrane_capacitance = parameters.Cm' + zeros(size(app(i, j).membrane_potential));
                    app(i, j).input_resistance = parameters.Rin' + zeros(size(app(i, j).membrane_potential));
                    app(i, j).resting_potential = parameters.Er' + zeros(size(app(i, j).membrane_potential));
                    app(i, j).excitatory_reversal_potential = parameters.Ee' + zeros(size(app(i, j).membrane_potential));
                    app(i, j).inhibitory_reversal_potential = parameters.Ei' + zeros(size(app(i, j).membrane_potential));
                    app(i, j).threshold_potential = parameters.Et' + zeros(size(app(i, j).membrane_potential));
                    app(i, j).activation_potential = parameters.Eact' + zeros(size(app(i, j).membrane_potential));
                    app(i, j).steady_state_potential = parameters.Ess' + zeros(size(app(i, j).membrane_potential));
                    app(i, j).alpha_multiplier = parameters.xalpha' + zeros(size(app(i, j).membrane_potential));
                    app(i, j).beta_multiplier = parameters.xbeta' + zeros(size(app(i, j).membrane_potential));
                    app(i, j).spikes_per_stimulus = parameters.sps' + zeros(size(app(i, j).membrane_potential));
                    app(i, j).reference_potential = parameters.Eref' + zeros(size(app(i, j).membrane_potential));
                    app(i, j).rate = parameters.rate';
                    app(i, j).npulses = parameters.npulses';
                end
            end
        end

        function app = build_analysis_arrays(app)
            [m, n] = size(app);
            for i = 1: m
                for j = 1: n
                    app(i, j).membrane_current = zeros(size(app(i, j).membrane_potential));
                    app(i, j).leakage_current = zeros(size(app(i, j).membrane_potential));
                    app(i, j).alpha = zeros(size(app(i, j).membrane_potential));
                    app(i, j).beta = zeros(size(app(i, j).membrane_potential));
                    app(i, j).activation_current = zeros(size(app(i, j).membrane_potential));
                    app(i, j).excitatory_conductance = zeros(size(app(i, j).membrane_potential));
                    app(i, j).inhibitory_conductance = zeros(size(app(i, j).membrane_potential));
                    app(i, j).excitatory_current = zeros(size(app(i, j).membrane_potential));
                    app(i, j).inhibitory_current = zeros(size(app(i, j).membrane_potential));
                    app(i, j).depolarizations = zeros(size(app(i, j).membrane_potential));
                    app(i, j).hyperpolarizations = zeros(size(app(i, j).membrane_potential));
                end
            end
        end

    end
    %% Filter methods
    methods
        function app = build_membrane_potential_filters(app, parameters)
            [m, n] = size(app);
            for i = 1: m
                for j = 1: n
                    app(i, j).membrane_potential_filters.firdifferentiator.window = designfilt('differentiatorfir', ...
                       'FilterOrder', parameters.firdifferentiator.order, ...
                       'PassbandFrequency', parameters.firdifferentiator.Fpass, ...
                       'StopbandFrequency', parameters.firdifferentiator.Fstop, ...
                       'SampleRate', app(i, j).fs);
                    app(i, j).membrane_potential_filters.firdifferentiator.delay = mean(grpdelay(app(i, j).membrane_potential_filters.firdifferentiator.window));
                    app(i, j).membrane_potential_filters.firlowpass.window = designfilt('lowpassfir', ...
                        'FilterOrder', parameters.firlowpass.order, ...
                        'PassbandFrequency', parameters.firlowpass.Fpass, ...
                        'StopbandFrequency', parameters.firlowpass.Fstop, ...
                        'SampleRate', app(i, j).fs);
                    app(i, j).membrane_potential_filters.firlowpass.delay = mean(grpdelay(app(i, j).membrane_potential_filters.firlowpass.window));
                end
            end
        end

        function app = build_membrane_current_filters(app, parameters)
            [m, n] = size(app);
            for i = 1: m
                for j = 1: n
                    app(i, j).membrane_current_filters.firlowpass.window = designfilt('lowpassfir', ...
                        'FilterOrder', parameters.firlowpass.order, ...
                        'PassbandFrequency', parameters.firlowpass.Fpass, ...
                        'StopbandFrequency', parameters.firlowpass.Fstop, ...
                        'SampleRate', app(i, j).fs);
                    app(i, j).membrane_current_filters.firlowpass.delay = mean(grpdelay(app(i, j).membrane_current_filters.firlowpass.window));
                end
            end
        end

        function app = filter_membrane_potential(app)
            [m, n] = size(app);
            for i = 1: m
                for j = 1: n
                    appender = zeros(app(i, j).membrane_potential_filters.firlowpass.delay*2, size(app(i, j).membrane_potential, 2));
                    Vm = cat(1, appender+app(i, j).membrane_potential(1, :), app(i, j).membrane_potential, appender+app(i, j).membrane_potential(end, :));
                    Vm = filter(app(i, j).membrane_potential_filters.firlowpass.window, Vm);
                    app(i, j).membrane_potential = Vm(app(i, j).membrane_potential_filters.firlowpass.delay*3 + 1: end - app(i, j).membrane_potential_filters.firlowpass.delay, :);
                end
            end
        end

        function app = filter_membrane_current(app)
            [m, n] = size(app);
            for i = 1: m
                for j = 1: n
                    appender = zeros(app(i, j).membrane_current_filters.firlowpass.delay*2, size(app(i, j).membrane_current, 2));
                    Im = cat(1, appender+app(i, j).membrane_current(1, :), app(i, j).membrane_current, appender+app(i, j).membrane_current(end, :));
                    Im = filter(app(i, j).membrane_current_filters.firlowpass.window, Im);
                    app(i, j).membrane_current = Im(app(i, j).membrane_current_filters.firlowpass.delay*3 + 1: end - app(i, j).membrane_current_filters.firlowpass.delay, :);
                end
            end
        end
    end

    %% Computing current methods
    methods

        function app = compute_membrane_current(app)
            [m, n] = size(app);
            for i = 1: m
                for j = 1: n
                    appender = zeros(app(i, j).membrane_potential_filters.firdifferentiator.delay*2, ...
                        size(app(i, j).membrane_potential, 2));
                    Vm = cat(1, appender+app(i, j).membrane_potential(1, :), app(i, j).membrane_potential, appender+app(i, j).membrane_potential(end, :));
                    dVmdt = filter(app(i, j).membrane_potential_filters.firdifferentiator.window, Vm);
                    app(i, j).membrane_current = app(i, j).membrane_capacitance .* dVmdt(app(i, j).membrane_potential_filters.firdifferentiator.delay*3 + 1: end-app(i, j).membrane_potential_filters.firdifferentiator.delay, :);
                end
            end
        end

        function app = compute_leakage_current(app)
            for i = 1: m
                for j = 1: n
                    app(i, j).leakage_current = (1./app(i, j).input_resistance).*(app(i, j).membrane_potential - app(i, j).resting_potential);
                end
            end
        end

        function app = compute_active_conductances(app)
            for i = 1: m
                for j = 1: n
                    app(i, j).alpha = ((1./app(i, j).input_resistance)./(2.*(app(i, j).activation_potential-app(i, j).steady_state_potential)));
                    app(i, j).beta = app(i, j).alpha.*(app(i, j).threshold_potential - app(i, j).steady_state_potential);
                    app(i, j).alpha = app(i, j).alpha.*app(i, j).alpha_multiplier;
                    app(i, j).beta = app(i, j).beta.*app(i, j).beta_multiplier;
                end
            end
        end

        function app = compute_activation_currents(app)
            app.compute_active_conductances();
            [m, n] = size(app);
            for i = 1: 1: m
               for j = 1: 1: n
                  app(i, j).activation_current = (app(i, j).alpha.*(app(i, j).membrane_potential-app(i, j).threshold_potential).*(app(i, j).membrane_potential-app(i, j).resting_potential)) ...
                          + (app(i, j).beta.*(app(i, j).membrane_potential-app(i, j).resting_potential));
               end
            end
        end

        function app = compute_passive_conductances(app)
            [m, n] = size(app);
            for i = 1: m
                for j = 1: n
                    samples = size(app(i, j).membrane_potential, 1);
                    A = zeros(2, 2, samples);
                    B = zeros(2, 1, samples);
                    A(1, 1, :) = sum((app(i, j).membrane_potential - app(i, j).excitatory_reversal_potential).^2, 2);
                    A(1, 2, :) = sum((app(i, j).membrane_potential - app(i, j).excitatory_reversal_potential).*(app(i, j).membrane_potential - app(i, j).inhibitory_reversal_potential), 2);
                    A(2, 1, :) = A(1, 2, :);
                    A(2, 2, :) = sum((app(i, j).membrane_potential - app(i, j).inhibitory_reversal_potential).^2, 2);
                    C = app(i, j).membrane_current - app(i, j).injected_current - app(i, j).activation_current + app(i, j).leakage_current;
                    B(1, 1, :) = -sum(C.*(app(i, j).membrane_potential - app(i, j).excitatory_reversal_potential), 2);
                    B(2, 1, :) = -sum(C.*(app(i, j).membrane_potential - app(i, j).inhibitory_reversal_potential), 2);
                    G = pagemtimes(pageinv(A), B);
                    app(i, j).excitatory_conductance = reshape(G(1, 1, :), [samples, 1]);
                    app(i, j).inhibitory_conductance = reshape(G(2, 1, :), [samples, 1]);
                end
            end
        end

        function app = compute_passive_currents(app)
            app = app.compute_passive_conductances();
            [m, n] = size(app);
            for i = 1: m
                for j = 1: n
                    app(i, j).excitatory_current = app(i, j).excitatory_conductance.*(app(i, j).membrane_potential - app(i, j).excitatory_conductance);
                    app(i, j).inhibitory_current = app(i, j).inhibitory_conductance.*(app(i, j).membrane_potential - app(i, j).inhibitory_conductance);
                end
            end
        end

    end

    methods
        function app = call(app)
            app = app.filter_membrane_potential();
            app = app.compute_membrane_current();
            app = app.filter_membrane_current();
            app = app.compute_leakage_current();
            app = app.compute_activation_currents();
            app = app.compute_passive_currents();
        end
    end
end