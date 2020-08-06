classdef app1 < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure          matlab.ui.Figure
        GridLayout        matlab.ui.container.GridLayout
        LeftPanel         matlab.ui.container.Panel
        VoiceButton       matlab.ui.control.Button
        AmbienceButton    matlab.ui.control.Button
        NoisyAudioButton  matlab.ui.control.Button
        MusicButton       matlab.ui.control.Button
        SOUNDLabel        matlab.ui.control.Label
        FILTERLabel       matlab.ui.control.Label
        AmbienceButton_2  matlab.ui.control.Button
        ENCRYPTLabel      matlab.ui.control.Label
        WhiteNoiseButton  matlab.ui.control.Button
        FilterButton      matlab.ui.control.Button
        RightPanel        matlab.ui.container.Panel
        UIAxes            matlab.ui.control.UIAxes
        UIAxes2           matlab.ui.control.UIAxes
    end

    % Properties that correspond to apps with auto-reflow
    properties (Access = private)
        onePanelWidth = 576;
    end

    
    properties (Access = public)
        Fs;     % Sampling rate
        N;      % Number of elements in each signal
        w;      % Omega
        t;      % Time
        
        recordedSignal;         % Original recorded audio signal
        recordedMusic;          % Music file
        recordedAmbience;       % Restaurant ambience noise
        
        noise;              % Ambience + Music
        maskedSignal;       % RecordedSignal + Noise
        filteredSignal;     % Signal being filtered
        whiteNoise;         % White noise to be encrypted
        encryptedSignal;    % RecordedSignal + White noise
        filterPushed = 0;
    end
    
    properties (Access = private)
        secretKey; % Description
        cipher;
    end
    
    methods (Access = private)
        
        % Fourier transform of signal to frequency domain
        function freq = signalFreq(app, signal)
            y = fft(signal(:,1), app.N) / app.N;
            freq = real(fftshift(y));
        end
        
        % Updates UIAxes graph
        function updateUIAxes(app, x, y, title, xlabel, ylabel, color)
            
            app.UIAxes.Title.String = title;
            app.UIAxes.XLabel.String = xlabel;
            app.UIAxes.YLabel.String = ylabel;
            plot(app.UIAxes, x, y, color);
            app.UIAxes.XLim = [0 15000];
            app.UIAxes.YLim = [0 0.0006];
        end
        
        % Updates UIAxes2 graph
        function updateUIAxes2(app, x, y, title, xlabel, ylabel, color)
            
            app.UIAxes2.Title.String = title;
            app.UIAxes2.XLabel.String = xlabel;
            app.UIAxes2.YLabel.String = ylabel;
            plot(app.UIAxes2, x, y, color);
            app.UIAxes2.XLim = [0 15000];
            app.UIAxes2.YLim = [0 0.0006];
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            % Reads in audio files and gets sampling rate
            [app.recordedSignal, app.Fs] = audioread('onetoten.wav');
            app.recordedMusic = audioread('feliznavidad.wav');
            app.recordedAmbience = audioread('restaurant.wav');
            
            
            app.N = numel(app.recordedSignal);
            app.w = (-(app.N/2):(app.N/2)-1) * (app.Fs / app.N);
            app.t = linspace(0,10,app.Fs*10);
            
            app.recordedAmbience = app.recordedAmbience(1:app.N)' * 0.6;    % Selects portion of ambience and lowers volume
            app.noise = app.recordedMusic + app.recordedAmbience;
            app.maskedSignal = app.recordedSignal + app.noise;
            app.whiteNoise = (max(app.recordedSignal) * 5) * awgn(app.recordedSignal, 10);
            app.encryptedSignal = app.maskedSignal + app.whiteNoise;
            assignin("base","whitenoise", app.whiteNoise);
            updateUIAxes2(app, app.t, app.noise, 'Restaurant Ambience', 'Time (sec)', 'Amplitude', '-b');
            app.UIAxes2.XLim = [0 10];
            app.UIAxes2.YLim = [max(app.noise)*-1 max(app.noise)];
            
            updateUIAxes(app, app.t, app.recordedSignal, 'Voice Audio', 'Time (sec)', 'Amplitude', '-b');
            app.UIAxes.XLim = [0 10];
            app.UIAxes.YLim = [max(app.recordedSignal)*-1 max(app.recordedSignal)];
        end

        % Button pushed function: VoiceButton
        function VoiceButtonPushed(app, event)
            voice = audioplayer(app.recordedSignal, app.Fs);
            voice.playblocking;
        end

        % Button pushed function: AmbienceButton
        function AmbienceButtonPushed(app, event)
            ambience = audioplayer(app.noise, app.Fs);
            ambience.playblocking;
        end

        % Button pushed function: NoisyAudioButton
        function NoisyAudioButtonPushed(app, event)
            masked = audioplayer(app.maskedSignal, app.Fs);
            masked.playblocking;
            
            cla(app.UIAxes);
            hold(app.UIAxes, 'on');
            updateUIAxes(app, app.t, app.maskedSignal, 'Masked Audio', 'Time (sec)', 'Amplitude', '-r');
            updateUIAxes(app, app.t, app.recordedSignal, 'Masked Audio', 'Time (sec)', 'Amplitude', '-b');
            hold(app.UIAxes, 'off');
            app.UIAxes.XLim = [0 10];
            app.UIAxes.YLim = [max(app.maskedSignal)*-1 max(app.maskedSignal)];
            
            y = signalFreq(app, app.maskedSignal);
            cla(app.UIAxes2);
            updateUIAxes2(app, app.w, y, 'Frequency of Masked Audio', 'Frequency (Hz)', 'Amplitude', '-b');
        end

        % Button pushed function: MusicButton
        function MusicButtonPushed(app, event)
            app.filteredSignal = app.maskedSignal - app.recordedMusic;
            gout = audioplayer(app.filteredSignal, app.Fs);
            
            gout.playblocking;
            
            y = signalFreq(app, app.filteredSignal);
            cla(app.UIAxes2);
            updateUIAxes2(app, app.w, y, 'Frequency of Filtered Audio', 'Frequency (Hz)', 'Amplitude', '-b');
            
            
            cla(app.UIAxes);
            hold(app.UIAxes, 'on');
            updateUIAxes(app, app.t, app.filteredSignal, 'Filtered Audio', 'Time (sec)', 'Amplitude', '-r');
            updateUIAxes(app, app.t, app.recordedSignal, 'Filtered Audio', 'Time (sec)', 'Amplitude', '-b');
            hold(app.UIAxes, 'off');
            app.UIAxes.XLim = [0 10];
            app.UIAxes.YLim = [max(app.filteredSignal)*-1 max(app.filteredSignal)];
        end

        % Button pushed function: AmbienceButton_2
        function AmbienceButton_2Pushed(app, event)
            switch app.filterPushed
                case 0
                    cutFreq = 5000 / (app.Fs/2);
                    app.filteredSignal = lowpass(app.filteredSignal, cutFreq);
                    foutplay = audioplayer(app.filteredSignal,app.Fs);
                    foutplay.playblocking;
                    
                    y = signalFreq(app, app.filteredSignal);
                    cla(app.UIAxes2);
                    updateUIAxes2(app, app.w, y, 'Frequency of Filtered Audio', 'Frequency (Hz)', 'Amplitude', '-b');
                    
                    cla(app.UIAxes);
                    hold(app.UIAxes, 'on');
                    updateUIAxes(app, app.t, app.filteredSignal, 'Filtered Audio', 'Time (sec)', 'Amplitude', '-r');
                    updateUIAxes(app, app.t, app.recordedSignal, 'Filtered Audio', 'Time (sec)', 'Amplitude', '-b');
                    hold(app.UIAxes, 'off');
                    app.UIAxes.XLim = [0 10];
                    app.UIAxes.YLim = [max(app.filteredSignal)*-1 max(app.filteredSignal)];
                case 1
                    beginFreq = 600 / (app.Fs/2);
                    endFreq = 2000 / (app.Fs/2);
                    wpass = [beginFreq endFreq];
                    
                    ambience2 = app.recordedAmbience * 1.1 + app.recordedSignal * 0.7;
                    ambience2 = bandpass(ambience2, wpass);
                    app.filteredSignal = bandpass(app.filteredSignal - ambience2, wpass) * 10;
                    foutplay = audioplayer(app.filteredSignal,app.Fs);
                    foutplay.playblocking;
                    
                    y = signalFreq(app, app.filteredSignal);
                    cla(app.UIAxes2);
                    updateUIAxes2(app, app.w, y, 'Frequency of Filtered Audio', 'Frequency (Hz)', 'Amplitude', '-b');
                    
                    cla(app.UIAxes);
                    hold(app.UIAxes, 'on');
                    updateUIAxes(app, app.t, app.filteredSignal, 'Filtered Audio', 'Time (sec)', 'Amplitude', '-r');
                    updateUIAxes(app, app.t, app.recordedSignal, 'Filtered Audio', 'Time (sec)', 'Amplitude', '-b');
                    hold(app.UIAxes, 'off');
                    app.UIAxes.XLim = [0 10];
                    app.UIAxes.YLim = [max(app.filteredSignal)*-1 max(app.filteredSignal)];
            end
            app.filterPushed = app.filterPushed + 1;
        end

        % Button pushed function: WhiteNoiseButton
        function WhiteNoiseButtonPushed(app, event)
            fout = audioplayer(app.encryptedSignal, app.Fs);
            fout.playblocking;
            
            cla(app.UIAxes);
            hold(app.UIAxes, 'on');
            updateUIAxes(app, app.t, app.encryptedSignal, 'White Noise Audio', 'Time (sec)', 'Amplitude', '-r');
            updateUIAxes(app, app.t, app.recordedSignal, 'White Noise Audio', 'Time (sec)', 'Amplitude', '-b');
            hold(app.UIAxes, 'off');
            app.UIAxes.XLim = [0 10];
            app.UIAxes.YLim = [max(app.encryptedSignal)*-1 max(app.encryptedSignal)];
            
            cla(app.UIAxes2);
            y = signalFreq(app, app.encryptedSignal);
            cla(app.UIAxes2);
            updateUIAxes2(app, app.w, y, 'Frequency of White Noise Audio', 'Frequency (Hz)', 'Amplitude', '-b');
            
            
        end

        % Button pushed function: FilterButton
        function FilterButtonPushed(app, event)
            filterEncrypt = app.encryptedSignal - app.recordedMusic;
            
            beginFreq = 600 / (app.Fs/2);
            endFreq = 2000 / (app.Fs/2);
            wpass = [beginFreq endFreq];
            
            ambience2 = app.whiteNoise * 0.7 + app.recordedAmbience * 1.1 + app.recordedSignal * 0.7;
            ambience2 = bandpass(ambience2, wpass);
            filterEncrypt = bandpass(filterEncrypt - ambience2, wpass) * 10;
            foutplay = audioplayer(filterEncrypt,app.Fs);
            foutplay.playblocking;
            
            y = signalFreq(app, filterEncrypt);
            cla(app.UIAxes2);
            updateUIAxes2(app, app.w, y, 'Frequency of Filtered Audio', 'Frequency (Hz)', 'Amplitude', '-b');
            
            cla(app.UIAxes);
            hold(app.UIAxes, 'on');
            updateUIAxes(app, app.t, filterEncrypt, 'Filtered Audio', 'Time (sec)', 'Amplitude', '-r');
            updateUIAxes(app, app.t, app.recordedSignal, 'Filtered Audio', 'Time (sec)', 'Amplitude', '-b');
            hold(app.UIAxes, 'off');
            app.UIAxes.XLim = [0 10];
            app.UIAxes.YLim = [max(filterEncrypt)*-1 max(filterEncrypt)];
        end

        % Changes arrangement of the app based on UIFigure width
        function updateAppLayout(app, event)
            currentFigureWidth = app.UIFigure.Position(3);
            if(currentFigureWidth <= app.onePanelWidth)
                % Change to a 2x1 grid
                app.GridLayout.RowHeight = {651, 651};
                app.GridLayout.ColumnWidth = {'1x'};
                app.RightPanel.Layout.Row = 2;
                app.RightPanel.Layout.Column = 1;
            else
                % Change to a 1x2 grid
                app.GridLayout.RowHeight = {'1x'};
                app.GridLayout.ColumnWidth = {251, '1x'};
                app.RightPanel.Layout.Row = 1;
                app.RightPanel.Layout.Column = 2;
            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.AutoResizeChildren = 'off';
            app.UIFigure.Position = [100 100 844 651];
            app.UIFigure.Name = 'UI Figure';
            app.UIFigure.SizeChangedFcn = createCallbackFcn(app, @updateAppLayout, true);

            % Create GridLayout
            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.ColumnWidth = {251, '1x'};
            app.GridLayout.RowHeight = {'1x'};
            app.GridLayout.ColumnSpacing = 0;
            app.GridLayout.RowSpacing = 0;
            app.GridLayout.Padding = [0 0 0 0];
            app.GridLayout.Scrollable = 'on';

            % Create LeftPanel
            app.LeftPanel = uipanel(app.GridLayout);
            app.LeftPanel.TitlePosition = 'centertop';
            app.LeftPanel.Layout.Row = 1;
            app.LeftPanel.Layout.Column = 1;

            % Create VoiceButton
            app.VoiceButton = uibutton(app.LeftPanel, 'push');
            app.VoiceButton.ButtonPushedFcn = createCallbackFcn(app, @VoiceButtonPushed, true);
            app.VoiceButton.FontName = 'Trebuchet MS';
            app.VoiceButton.FontSize = 20;
            app.VoiceButton.FontWeight = 'bold';
            app.VoiceButton.Position = [52 553 148 40];
            app.VoiceButton.Text = 'Voice';

            % Create AmbienceButton
            app.AmbienceButton = uibutton(app.LeftPanel, 'push');
            app.AmbienceButton.ButtonPushedFcn = createCallbackFcn(app, @AmbienceButtonPushed, true);
            app.AmbienceButton.FontName = 'Trebuchet MS';
            app.AmbienceButton.FontSize = 20;
            app.AmbienceButton.FontWeight = 'bold';
            app.AmbienceButton.Position = [53 502 148 40];
            app.AmbienceButton.Text = 'Ambience';

            % Create NoisyAudioButton
            app.NoisyAudioButton = uibutton(app.LeftPanel, 'push');
            app.NoisyAudioButton.ButtonPushedFcn = createCallbackFcn(app, @NoisyAudioButtonPushed, true);
            app.NoisyAudioButton.FontName = 'Trebuchet MS';
            app.NoisyAudioButton.FontSize = 20;
            app.NoisyAudioButton.FontWeight = 'bold';
            app.NoisyAudioButton.Position = [52 449 148 40];
            app.NoisyAudioButton.Text = 'Noisy Audio';

            % Create MusicButton
            app.MusicButton = uibutton(app.LeftPanel, 'push');
            app.MusicButton.ButtonPushedFcn = createCallbackFcn(app, @MusicButtonPushed, true);
            app.MusicButton.FontName = 'Trebuchet MS';
            app.MusicButton.FontSize = 20;
            app.MusicButton.FontWeight = 'bold';
            app.MusicButton.Position = [51 329 148 40];
            app.MusicButton.Text = 'Music';

            % Create SOUNDLabel
            app.SOUNDLabel = uilabel(app.LeftPanel);
            app.SOUNDLabel.HorizontalAlignment = 'center';
            app.SOUNDLabel.FontName = 'Trebuchet MS';
            app.SOUNDLabel.FontSize = 35;
            app.SOUNDLabel.FontWeight = 'bold';
            app.SOUNDLabel.Position = [67 592 118 44];
            app.SOUNDLabel.Text = 'SOUND';

            % Create FILTERLabel
            app.FILTERLabel = uilabel(app.LeftPanel);
            app.FILTERLabel.HorizontalAlignment = 'center';
            app.FILTERLabel.FontName = 'Trebuchet MS';
            app.FILTERLabel.FontSize = 35;
            app.FILTERLabel.FontWeight = 'bold';
            app.FILTERLabel.Position = [67 368 118 44];
            app.FILTERLabel.Text = 'FILTER';

            % Create AmbienceButton_2
            app.AmbienceButton_2 = uibutton(app.LeftPanel, 'push');
            app.AmbienceButton_2.ButtonPushedFcn = createCallbackFcn(app, @AmbienceButton_2Pushed, true);
            app.AmbienceButton_2.FontName = 'Trebuchet MS';
            app.AmbienceButton_2.FontSize = 20;
            app.AmbienceButton_2.FontWeight = 'bold';
            app.AmbienceButton_2.Position = [51 277 148 40];
            app.AmbienceButton_2.Text = 'Ambience';

            % Create ENCRYPTLabel
            app.ENCRYPTLabel = uilabel(app.LeftPanel);
            app.ENCRYPTLabel.HorizontalAlignment = 'center';
            app.ENCRYPTLabel.FontName = 'Trebuchet MS';
            app.ENCRYPTLabel.FontSize = 35;
            app.ENCRYPTLabel.FontWeight = 'bold';
            app.ENCRYPTLabel.Position = [48 190 155 44];
            app.ENCRYPTLabel.Text = 'ENCRYPT';

            % Create WhiteNoiseButton
            app.WhiteNoiseButton = uibutton(app.LeftPanel, 'push');
            app.WhiteNoiseButton.ButtonPushedFcn = createCallbackFcn(app, @WhiteNoiseButtonPushed, true);
            app.WhiteNoiseButton.FontName = 'Trebuchet MS';
            app.WhiteNoiseButton.FontSize = 20;
            app.WhiteNoiseButton.FontWeight = 'bold';
            app.WhiteNoiseButton.Position = [52 151 148 40];
            app.WhiteNoiseButton.Text = 'White Noise';

            % Create FilterButton
            app.FilterButton = uibutton(app.LeftPanel, 'push');
            app.FilterButton.ButtonPushedFcn = createCallbackFcn(app, @FilterButtonPushed, true);
            app.FilterButton.FontName = 'Trebuchet MS';
            app.FilterButton.FontSize = 20;
            app.FilterButton.FontWeight = 'bold';
            app.FilterButton.Position = [52 95 148 40];
            app.FilterButton.Text = 'Filter';

            % Create RightPanel
            app.RightPanel = uipanel(app.GridLayout);
            app.RightPanel.Layout.Row = 1;
            app.RightPanel.Layout.Column = 2;

            % Create UIAxes
            app.UIAxes = uiaxes(app.RightPanel);
            title(app.UIAxes, 'Sound Data')
            xlabel(app.UIAxes, 'Time')
            ylabel(app.UIAxes, 'Amplitude')
            app.UIAxes.PlotBoxAspectRatio = [1.94573643410853 1 1];
            app.UIAxes.FontName = 'Trebuchet MS';
            app.UIAxes.Position = [7 325 552 319];

            % Create UIAxes2
            app.UIAxes2 = uiaxes(app.RightPanel);
            title(app.UIAxes2, 'Restaurant Ambience')
            xlabel(app.UIAxes2, 'Frequency (Hz)')
            ylabel(app.UIAxes2, 'Amplitude')
            app.UIAxes2.PlotBoxAspectRatio = [1.94573643410853 1 1];
            app.UIAxes2.FontName = 'Trebuchet MS';
            app.UIAxes2.Position = [7 7 552 319];

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = app1

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end