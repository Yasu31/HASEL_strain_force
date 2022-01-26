classdef ForceControl_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        BrowseButton                    matlab.ui.control.Button
        GoButton                        matlab.ui.control.StateButton
        SelectfilepathEditFieldLabel    matlab.ui.control.Label
        SelectfilepathEditField         matlab.ui.control.EditField
        RawfilenameEditFieldLabel       matlab.ui.control.Label
        RawfilenameEditField            matlab.ui.control.EditField
        ProcessedfilenameLabel          matlab.ui.control.Label
        ProcessedfilenameEditField      matlab.ui.control.EditField
        SaverawfileCheckBox             matlab.ui.control.CheckBox
        SetupPanel                      matlab.ui.container.Panel
        ao0ao1ai0ai1ai2Label            matlab.ui.control.Label
        VoltageParametersPanel          matlab.ui.container.Panel
        VoltagefrequencyEditFieldLabel  matlab.ui.control.Label
        VoltagefrequencyEditField       matlab.ui.control.NumericEditField
        HzLabel_2                       matlab.ui.control.Label
        MaxvoltageEditFieldLabel        matlab.ui.control.Label
        MaxvoltageEditField             matlab.ui.control.NumericEditField
        kVLabel                         matlab.ui.control.Label
        ReversepolarityCheckBox         matlab.ui.control.CheckBox
        SignaltypeLabel                 matlab.ui.control.Label
        SignaltypeDropDown              matlab.ui.control.DropDown
        RampangleEditFieldLabel         matlab.ui.control.Label
        RampangleEditField              matlab.ui.control.NumericEditField
        kVsLabel                        matlab.ui.control.Label
        CalibrationPanel                matlab.ui.container.Panel
        SamplerateEditFieldLabel        matlab.ui.control.Label
        SamplerateEditField             matlab.ui.control.NumericEditField
        HzLabel                         matlab.ui.control.Label
        TREKvoltageconstantkVEditFieldLabel  matlab.ui.control.Label
        TREKvoltageconstantkVEditField  matlab.ui.control.NumericEditField
        VkVLabel                        matlab.ui.control.Label
        MTforceconstantkFEditFieldLabel  matlab.ui.control.Label
        MTforceconstantkFEditField      matlab.ui.control.NumericEditField
        MTlengthconstantkLEditFieldLabel  matlab.ui.control.Label
        MTlengthconstantkLEditField     matlab.ui.control.NumericEditField
        NVLabel                         matlab.ui.control.Label
        mmVLabel                        matlab.ui.control.Label
        ForceParametersPanel            matlab.ui.container.Panel
        MaxforceEditFieldLabel          matlab.ui.control.Label
        MaxforceEditField               matlab.ui.control.NumericEditField
        NLabel                          matlab.ui.control.Label
        NumberofforcestepsLabel         matlab.ui.control.Label
        NumberofforcestepsEditField     matlab.ui.control.NumericEditField
        inclzeroLabel                   matlab.ui.control.Label
        LogdistributionCheckBox         matlab.ui.control.CheckBox
        NumberofvoltcyclesperstepEditFieldLabel  matlab.ui.control.Label
        NumberofvoltcyclesperstepEditField  matlab.ui.control.NumericEditField
        PressStopwhentestiscompletedtosavedataLabel  matlab.ui.control.Label
        MonitorlimittripstatusCheckBox  matlab.ui.control.CheckBox
        Lamp                            matlab.ui.control.Lamp
        UIAxes                          matlab.ui.control.UIAxes
    end

    
    methods (Access = private)
        
        function fullSignal = buildSignal(app)
            global kV kF
            
            sampRate = app.SamplerateEditField.Value;
            frequency = app.VoltagefrequencyEditField.Value;
            maxVoltage = app.MaxvoltageEditField.Value/kV;
            numVoltsPerStep = app.NumberofvoltcyclesperstepEditField.Value;
            numForceSteps = app.NumberofforcestepsEditField.Value;
            maxForce = app.MaxforceEditField.Value;
            
            cycleSamples = sampRate/frequency; %samples/cycle
            totalCycles = numForceSteps*numVoltsPerStep;
            totalSamples = cycleSamples*totalCycles;
            
            voltageCycle = zeros(cycleSamples, 1);
            voltageSignal = zeros(totalSamples, 1);
            forceSignal = voltageSignal;
            
            % Build voltage signal
            switch app.SignaltypeDropDown.Value
                case 'Step'
                    numHold = floor(cycleSamples/3);
                    numRamp = 1;
                    
                    voltageCycle(numHold + 1: numHold + numRamp, 1) = linspace(0, maxVoltage, numRamp).';
                    voltageCycle(numHold + numRamp + 1: 2*numHold + numRamp, 1) = maxVoltage;
                    voltageCycle(2*numHold + numRamp + 1: end, 1) = linspace(maxVoltage, 0, numRamp).';
                    % this end is trying to terminate the switch
                case 'Ramped square'
                    numHold = floor(cycleSamples/3);
                    numRamp = ceil(app.MaxvoltageEditField.Value/app.RampangleEditField.Value*app.SamplerateEditField.Value);
                    
                    voltageCycle(numHold + 1: numHold + numRamp, 1) = linspace(0, maxVoltage, numRamp).';
                    voltageCycle(numHold + numRamp + 1: 2*numHold + numRamp, 1) = maxVoltage;
                    voltageCycle(2*numHold + numRamp + 1: 2*numHold + 2*numRamp, 1) = linspace(maxVoltage, 0, numRamp).';
                    % this end is trying to terminate the switch
                otherwise
                    voltageCycle(1:round(cycleSamples/2), 1) = linspace(0, maxVoltage, round(cycleSamples/2)).';
                    voltageCycle(round(cycleSamples/2) + 1: end, 1) = linspace(maxVoltage, 0, floor(cycleSamples/2)).';
                    % I don't actually think we need to bother
                    % rounding? Has to do with sample rate
            end
            
            voltageSignal(1: cycleSamples, 1) = voltageCycle;
            for i = 1:totalCycles - 1
                j = i*cycleSamples;
                if app.ReversepolarityCheckBox.Value
                    voltageCycle = -voltageCycle;
                end
                voltageSignal(j + 1: j+cycleSamples, 1) = voltageCycle;
            end
            
            % Build force signal
            stepSamples = cycleSamples * numVoltsPerStep; % num samples per force step
            
            if app.LogdistributionCheckBox.Value
                for i = 1: numForceSteps - 1
                    forceSignal(i*stepSamples + 1: (i + 1)*stepSamples, 1) = (maxForce/kF)*(1 - (log(numForceSteps - i)/log(numForceSteps)));
                end
            else
                if numForceSteps == 1
                    forceSignal(:, 1) = maxForce/kF;
                else
                    reference = linspace(0, maxForce/kF, numForceSteps);
                    for i = 0:numForceSteps - 1
                        forceSignal(i*stepSamples + 1: (i + 1)*stepSamples, 1) = reference(i + 1);
                    end
                end
            end
            forceSignal(end, 1) = 0;
            
            fullSignal = [voltageSignal, forceSignal];
        end
        
        function processedCurve = generateFSCurve(app)
            global kF kL forceArr lengthArr
            sampleRate = app.SamplerateEditField.Value;
            frequency = app.VoltagefrequencyEditField.Value;
            voltsPerStep = app.NumberofvoltcyclesperstepEditField.Value;
            numForceSteps = app.NumberofforcestepsEditField.Value;
            
            smoothingFactor = 100;
            % Need to make sure this is OK
            processedForce = zeros(numForceSteps, 1);
            processedStroke = zeros(numForceSteps, 1);
            
            displacement = medfilt1(lengthArr, smoothingFactor);
            
            samplesPerVolt = sampleRate/frequency; % num samples per volt
            samplesPerForceStep = samplesPerVolt * voltsPerStep; % num samples per displacement step
            
            temp = zeros(voltsPerStep, 1);
            for i = 1: numForceSteps
                
                startIndex = (i - 1)*samplesPerForceStep + 1;
                endIndex = i*samplesPerForceStep;
                processedForce(i) = mean(forceArr(startIndex: endIndex)) * kF;
                
                for j = 1: voltsPerStep
                    startIndex2 = startIndex + (j - 1)*samplesPerVolt;
                    midIndex2 = startIndex2 + (1/2)*samplesPerVolt;
                    endIndex2 = (startIndex - 1) + j*samplesPerVolt;
                    temp(j) = (max(displacement(startIndex2: midIndex2)) - min(displacement(midIndex2: endIndex2))) * kL;
                    
                end
                processedStroke(i) = mean(temp);
            end
            
            processedCurve = [processedStroke, processedForce];
        end
        
        function buildPreview(app)
            global kV kF
            sampRate = app.SamplerateEditField.Value;
            maxVoltage = app.MaxvoltageEditField.Value;
            
            fullSignal = buildSignal(app);
            time = linspace(0, length(fullSignal)/sampRate, length(fullSignal));
            
            yyaxis(app.UIAxes, 'right');
            plot(app.UIAxes, time, fullSignal(:, 2)*kF);
            ylabel(app.UIAxes, 'Force (N)');
            
            yyaxis(app.UIAxes, 'left');
            plot(app.UIAxes, time, fullSignal(:, 1)*kV);
            ylim(app.UIAxes, [(-1.5)*maxVoltage, 1.5*maxVoltage])
            ylabel(app.UIAxes, 'Voltage (kV)');
            
        end
        
        function storeData(app, ~, ~)
            % This function is called every n = scansAvailableFcnCount data
            % points read by the DAQ
            global d kF kL voltageArr forceArr lengthArr triggerArr scanCount lastDataIndex
            
            numScansAvailable = d.NumScansAvailable;
            if numScansAvailable == 0
                return;
            end
            scanCount = scanCount + 1;
            
            startIndex = (scanCount - 1)*d.ScansAvailableFcnCount + 1;
            % location to put next data
            endIndex = (startIndex - 1) + numScansAvailable;
            % location of end of new data
            lastDataIndex = endIndex;
            % this global index tells the program where the last data
            % point is, in case of test interruption
            
            % Read available data from DAQ
            scanData = read(d, numScansAvailable, "OutputFormat", "Matrix");
            voltage = scanData(:, 1);
            voltageArr(startIndex: endIndex) = voltage;
            % channel 1 is voltage input (in volts)
            force = scanData(:, 2);
            forceArr(startIndex: endIndex) = force;
            % channel 2 is force input (in volts)
            displacement = scanData(:, 3);
            lengthArr(startIndex: endIndex) = displacement;
            % channel 3 is length input (in volts)
            trigger = scanData(:, 5);
            triggerArr(startIndex: endIndex) = trigger;
            % channel 5 is trigger input (in volts) <- ch4 is used for trek limit <- currently not used
            
            % Plot data every cycle
            x = linspace(cast(startIndex, 'double'), cast(endIndex, 'double'), length(force));
            yyaxis(app.UIAxes, 'left');
            plot(app.UIAxes, x, displacement*kL, '-');
            yyaxis(app.UIAxes, 'right');
            plot(app.UIAxes, x, force*kF, '-');
            
            trip = scanData(end, 4);
            % channel 4 is limit/trip status
            if trip < 4 && app.MonitorlimittripstatusCheckBox.Value
                app.Lamp.Color = 'red';
                app.GoButton.Value = 0;
                GoButtonValueChanged(app);
            end
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            % DAQ Dev1 ao0 = Voltage output to Trek
            % DAQ Dev1 ao1 = Force output to muscle tester
            
            % DAQ Dev1 ai0 = Voltage monitor from Trek
            % DAQ Dev1 ai1 = Force monitor from muscle tester
            % DAQ Dev1 ai2 = Displacement monitor from muscle tester
            
            global d kF kL kV
            
            kV = app.TREKvoltageconstantkVEditField.Value;
            kF = app.MTforceconstantkFEditField.Value;
            kL = app.MTlengthconstantkLEditField.Value;
            
            app.RawfilenameEditField.Enable = 0;
            app.GoButton.Text = 'Go (inactive)';
            
            buildPreview(app);
            
            d = daq("ni");
            d.Rate = app.SamplerateEditField.Value;
            
            d.ScansAvailableFcn = @(src, event) storeData(app, src, event);
            % call storeData fcn when scans are available
            
            d.ScansAvailableFcnCount = app.SamplerateEditField.Value/app.VoltagefrequencyEditField.Value;
            % by default, call storeData every cycle
            
            devName = "Dev1";
            
            addoutput(d, devName, "ao0", "Voltage");
            % TREK voltage input
            addoutput(d, devName, "ao1", "Voltage");
            % MT force input
            
            addinput(d, devName, "ai0", "Voltage");
            % TREK voltage monitor
            addinput(d, devName, "ai1", "Voltage");
            % MT force out
            addinput(d, devName, "ai2", "Voltage");
            % MT length out
            addinput(d, devName, "ai7", "Voltage");
            % TREK limit/trip status
            addinput(d, devName, "ai6", "Voltage");
            % trigger
            
        end

        % Button pushed function: BrowseButton
        function BrowseButtonPushed(app, event)
            filepath = uigetdir;
            try
                app.SelectfilepathEditField.Value = filepath;
            catch
                uiwait(msgbox("No filepath selected", "Warning", 'warn', 'modal'));
                app.SelectfilepathEditField.Value = "";
            end
        end

        % Value changed function: GoButton
        function GoButtonValueChanged(app, event)
            global d voltageArr forceArr lengthArr triggerArr scanCount lastDataIndex...
                kV kF kL
            
            if app.GoButton.Value
                
                % Check for valid filenames
                if app.ProcessedfilenameEditField == ""
                    uiwait(msgbox("Empty filename", "Error", 'modal'));
                    app.GoButton.Value = 0;
                    buildPreview(app);
                    return
                elseif app.SaverawfileCheckBox.Value && app.RawfilenameEditField == ""
                    uiwait(msgbox("Empty filename", "Error", 'modal'));
                    app.GoButton.Value = 0;
                    buildPreview(app);
                    return
                end
                
                app.UIAxes.YAxis(2).Visible = 'on';
                xlabel(app.UIAxes, 'Sample Number');
                yyaxis(app.UIAxes, 'right');
                cla(app.UIAxes);
                ylim(app.UIAxes, 'auto');
                hold(app.UIAxes, 'on');
                ylabel(app.UIAxes, 'Force (N)');
                yyaxis(app.UIAxes, 'left');
                cla(app.UIAxes);
                ylim(app.UIAxes, 'auto');
                hold(app.UIAxes, 'on');
                ylabel(app.UIAxes, 'Displacement (mm)');
                
                % Check for valid filenames
                if app.SaverawfileCheckBox.Value && app.RawfilenameEditField.Value == ""
                    uiwait(msgbox("Empty filename", "Error", 'modal'));
                    app.GoButton.Value = 0;
                    return
                elseif app.ProcessedfilenameEditField.Value == ""
                    uiwait(msgbox("Empty filename", "Error", 'modal'));
                    app.GoButton.Value = 0;
                    return
                end
                
                app.GoButton.Text = "Stop (active)";
                app.GoButton.BackgroundColor = 'red';
                if app.MonitorlimittripstatusCheckBox.Value
                    app.Lamp.Color = 'green';
                end
                
                % Build output signal and preload
                fullSignal = buildSignal(app);
                voltageArr = zeros(length(fullSignal(:, 1)), 1);
                forceArr = voltageArr;
                lengthArr = voltageArr;
                triggerArr = voltageArr;
                
                scanCount = 0;
                preload(d, fullSignal);
                start(d);
            else
                % End test
                
                % Stop the DAQ
                if d.Running
                    stop(d);
                end
                
                % Read residual data from DAQ
                if d.NumScansAvailable > 0
                    storeData(app, d, 0);
                end
                
                switch app.SignaltypeDropDown.Value
                    case 'Step'
                        textInputPattern = 'Stepinput';
                    case 'Ramped square'
                        textInputPattern = ['Rampedsquare_', num2str(app.RampangleEditField.Value, '%02.0fkVs')];
                    case 'Triangle'
                        textInputPattern = 'Triangle';
                end
                
                textPara = [...
                    num2str(app.VoltagefrequencyEditField.Value*10, '_%02.0f'), 'Hz_',...
                    num2str(app.MaxvoltageEditField.Value, '%01.0f'), 'kV_',...
                    textInputPattern, '_', datestr(now,'yyyy_mm_dd_HHMM')];
                processedFilename = fullfile(app.SelectfilepathEditField.Value, [app.ProcessedfilenameEditField.Value, textPara]);
                
                if app.SaverawfileCheckBox.Value
                    time = linspace(0, length(voltageArr)/app.SamplerateEditField.Value, length(voltageArr)).';
                    %                     rawFilename = fullfile(app.SelectfilepathEditField.Value, app.RawfilenameEditField.Value);
                    rawFilename = fullfile(app.SelectfilepathEditField.Value, ['raw_', app.ProcessedfilenameEditField.Value, textPara]);
                    %                     writetable(table(time(1:lastDataIndex), voltageArr(1:lastDataIndex)*kV, forceArr(1:lastDataIndex)*kF,...
                    writetable(table(time(1:lastDataIndex), voltageArr(1:lastDataIndex)*kV, forceArr(1:lastDataIndex)*-kF,...
                        lengthArr(1:lastDataIndex)*kL, triggerArr(1: lastDataIndex), 'VariableNames', {'Time [s]', 'Voltage [kV]', 'Force [N]', 'Length [mm]', 'TriggerSignal [V]'}), rawFilename);
                end
                
                processedCurve = generateFSCurve(app);
                
                %                 processedFilename = fullfile(app.SelectfilepathEditField.Value, [app.ProcessedfilenameEditField.Value, textPara]);
                writetable(table(processedCurve(:, 1), processedCurve(:, 2), 'VariableNames',...
                    {'Stroke (mm)', 'Force (N)'}), processedFilename);
                
                % Fush the DAQ and ensure zero voltage
                flush(d);
                write(d, [0, 0]);
                
                app.UIAxes.YAxis(2).Visible = 'off';
                yyaxis(app.UIAxes, 'right')
                cla(app.UIAxes);
                yyaxis(app.UIAxes, 'left')
                cla(app.UIAxes);
                
                plot(app.UIAxes, processedCurve(:, 1), processedCurve(:, 2));
                xlabel(app.UIAxes, 'Displacement (mm)');
                ylabel(app.UIAxes, 'Force (N)');
                
                app.GoButton.BackgroundColor = [0.96, 0.96, 0.96];
                app.GoButton.Text = {'Go', '(inactive)'};
            end
        end

        % Value changed function: SaverawfileCheckBox
        function SaverawfileCheckBoxValueChanged(app, event)
            if app.SaverawfileCheckBox.Value
                app.RawfilenameEditField.Enable = 1;
            else
                app.RawfilenameEditField.Enable = 0;
            end
        end

        % Value changed function: SamplerateEditField
        function SamplerateEditFieldValueChanged(app, event)
            global d
            d.Rate = app.SamplerateEditField.Value;
            % change scansAvailableFcnCount here
        end

        % Value changed function: TREKvoltageconstantkVEditField
        function TREKvoltageconstantkVEditFieldValueChanged(app, event)
            global kV
            kV = app.TREKvoltageconstantkVEditField.Value;
        end

        % Value changed function: MTforceconstantkFEditField
        function MTforceconstantkFEditFieldValueChanged(app, event)
            global kF
            kF = app.MTforceconstantkFEditField.Value;
        end

        % Value changed function: MTlengthconstantkLEditField
        function MTlengthconstantkLEditFieldValueChanged(app, event)
            global kL
            kL = app.MTlengthconstantkLEditField.Value;
        end

        % Value changed function: VoltagefrequencyEditField
        function VoltagefrequencyEditFieldValueChanged(app, event)
            buildPreview(app);
        end

        % Value changed function: MaxvoltageEditField
        function MaxvoltageEditFieldValueChanged(app, event)
            buildPreview(app);
        end

        % Value changed function: NumberofvoltcyclesperstepEditField
        function NumberofvoltcyclesperstepEditFieldValueChanged(app, event)
            buildPreview(app);
        end

        % Value changed function: ReversepolarityCheckBox
        function ReversepolarityCheckBoxValueChanged(app, event)
            buildPreview(app);
        end

        % Value changed function: LogdistributionCheckBox
        function LogdistributionCheckBoxValueChanged(app, event)
            buildPreview(app);
        end

        % Value changed function: MaxforceEditField
        function MaxforceEditFieldValueChanged(app, event)
            buildPreview(app);
        end

        % Value changed function: NumberofforcestepsEditField
        function NumberofforcestepsEditFieldValueChanged(app, event)
            if app.NumberofforcestepsEditField.Value == 1
                app.LogdistributionCheckBox.Value = 0;
                app.LogdistributionCheckBox.Enable = 0;
            elseif ~app.LogdistributionCheckBox.Enable
                app.LogdistributionCheckBox.Enable = 1;
            end
            
            buildPreview(app);
        end

        % Value changed function: MonitorlimittripstatusCheckBox
        function MonitorlimittripstatusCheckBoxValueChanged(app, event)
            if app.MonitorlimittripstatusCheckBox.Value
                app.Lamp.Enable = 1;
                app.Lamp.Color = 'green';
            else
                app.Lamp.Enable = 0;
                app.Lamp.Color = [0.96, 0.96, 0.96];
            end
        end

        % Value changed function: SignaltypeDropDown
        function SignaltypeDropDownValueChanged(app, event)
            buildPreview(app);
        end

        % Value changed function: RampangleEditField
        function RampangleEditFieldValueChanged(app, event)
            buildPreview(app);
            
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 822 489];
            app.UIFigure.Name = 'MATLAB App';

            % Create BrowseButton
            app.BrowseButton = uibutton(app.UIFigure, 'push');
            app.BrowseButton.ButtonPushedFcn = createCallbackFcn(app, @BrowseButtonPushed, true);
            app.BrowseButton.Position = [699 449 100 22];
            app.BrowseButton.Text = 'Browse';

            % Create GoButton
            app.GoButton = uibutton(app.UIFigure, 'state');
            app.GoButton.ValueChangedFcn = createCallbackFcn(app, @GoButtonValueChanged, true);
            app.GoButton.Text = 'Go';
            app.GoButton.BackgroundColor = [0.9608 0.9608 0.9608];
            app.GoButton.FontSize = 24;
            app.GoButton.FontWeight = 'bold';
            app.GoButton.Position = [641 253 146 53];

            % Create SelectfilepathEditFieldLabel
            app.SelectfilepathEditFieldLabel = uilabel(app.UIFigure);
            app.SelectfilepathEditFieldLabel.HorizontalAlignment = 'right';
            app.SelectfilepathEditFieldLabel.Position = [584 449 101 22];
            app.SelectfilepathEditFieldLabel.Text = 'Select file path:';

            % Create SelectfilepathEditField
            app.SelectfilepathEditField = uieditfield(app.UIFigure, 'text');
            app.SelectfilepathEditField.Position = [533 419 268 22];

            % Create RawfilenameEditFieldLabel
            app.RawfilenameEditFieldLabel = uilabel(app.UIFigure);
            app.RawfilenameEditFieldLabel.HorizontalAlignment = 'right';
            app.RawfilenameEditFieldLabel.Position = [534 350 81 22];
            app.RawfilenameEditFieldLabel.Text = 'Raw filename:';

            % Create RawfilenameEditField
            app.RawfilenameEditField = uieditfield(app.UIFigure, 'text');
            app.RawfilenameEditField.Position = [627 350 173 22];
            app.RawfilenameEditField.Value = 'raw_';

            % Create ProcessedfilenameLabel
            app.ProcessedfilenameLabel = uilabel(app.UIFigure);
            app.ProcessedfilenameLabel.HorizontalAlignment = 'right';
            app.ProcessedfilenameLabel.Position = [502 385 114 22];
            app.ProcessedfilenameLabel.Text = 'Processed filename:';

            % Create ProcessedfilenameEditField
            app.ProcessedfilenameEditField = uieditfield(app.UIFigure, 'text');
            app.ProcessedfilenameEditField.Position = [628 385 173 22];
            app.ProcessedfilenameEditField.Value = '20x60_EUP_FR3_60';

            % Create SaverawfileCheckBox
            app.SaverawfileCheckBox = uicheckbox(app.UIFigure);
            app.SaverawfileCheckBox.ValueChangedFcn = createCallbackFcn(app, @SaverawfileCheckBoxValueChanged, true);
            app.SaverawfileCheckBox.Text = 'Save raw file';
            app.SaverawfileCheckBox.Position = [707 319 90 22];
            app.SaverawfileCheckBox.Value = true;

            % Create SetupPanel
            app.SetupPanel = uipanel(app.UIFigure);
            app.SetupPanel.TitlePosition = 'centertop';
            app.SetupPanel.Title = 'Setup';
            app.SetupPanel.FontWeight = 'bold';
            app.SetupPanel.FontSize = 14;
            app.SetupPanel.Position = [24 16 187 186];

            % Create ao0ao1ai0ai1ai2Label
            app.ao0ao1ai0ai1ai2Label = uilabel(app.SetupPanel);
            app.ao0ao1ai0ai1ai2Label.Position = [12 11 175 143];
            app.ao0ao1ai0ai1ai2Label.Text = {'AO0: TREK "voltage in"'; 'AO1: Muscle tester "force in"'; 'AI0: TREK "voltage monitor"'; 'AI1: Muscle tester "force out"'; 'AI2: Muscle tester "length out"'; 'AI6: Trigger signal'; ''; 'Setup:'; '1) Turn length knob to 10 V'; '2) Turn force knob to 0 V'; ''};

            % Create VoltageParametersPanel
            app.VoltageParametersPanel = uipanel(app.UIFigure);
            app.VoltageParametersPanel.TitlePosition = 'centertop';
            app.VoltageParametersPanel.Title = 'Voltage Parameters';
            app.VoltageParametersPanel.FontWeight = 'bold';
            app.VoltageParametersPanel.FontSize = 14;
            app.VoltageParametersPanel.Position = [414 16 187 186];

            % Create VoltagefrequencyEditFieldLabel
            app.VoltagefrequencyEditFieldLabel = uilabel(app.VoltageParametersPanel);
            app.VoltagefrequencyEditFieldLabel.HorizontalAlignment = 'right';
            app.VoltagefrequencyEditFieldLabel.Position = [1 134 114 22];
            app.VoltagefrequencyEditFieldLabel.Text = 'Voltage frequency';

            % Create VoltagefrequencyEditField
            app.VoltagefrequencyEditField = uieditfield(app.VoltageParametersPanel, 'numeric');
            app.VoltagefrequencyEditField.Limits = [0 Inf];
            app.VoltagefrequencyEditField.ValueChangedFcn = createCallbackFcn(app, @VoltagefrequencyEditFieldValueChanged, true);
            app.VoltagefrequencyEditField.Position = [123 134 33 22];
            app.VoltagefrequencyEditField.Value = 0.5;

            % Create HzLabel_2
            app.HzLabel_2 = uilabel(app.VoltageParametersPanel);
            app.HzLabel_2.Position = [158 134 25 22];
            app.HzLabel_2.Text = 'Hz';

            % Create MaxvoltageEditFieldLabel
            app.MaxvoltageEditFieldLabel = uilabel(app.VoltageParametersPanel);
            app.MaxvoltageEditFieldLabel.HorizontalAlignment = 'right';
            app.MaxvoltageEditFieldLabel.Position = [43 96 70 22];
            app.MaxvoltageEditFieldLabel.Text = 'Max voltage';

            % Create MaxvoltageEditField
            app.MaxvoltageEditField = uieditfield(app.VoltageParametersPanel, 'numeric');
            app.MaxvoltageEditField.Limits = [0 20];
            app.MaxvoltageEditField.ValueChangedFcn = createCallbackFcn(app, @MaxvoltageEditFieldValueChanged, true);
            app.MaxvoltageEditField.Position = [123 96 31 22];
            app.MaxvoltageEditField.Value = 7;

            % Create kVLabel
            app.kVLabel = uilabel(app.VoltageParametersPanel);
            app.kVLabel.Position = [158 96 25 22];
            app.kVLabel.Text = 'kV';

            % Create ReversepolarityCheckBox
            app.ReversepolarityCheckBox = uicheckbox(app.VoltageParametersPanel);
            app.ReversepolarityCheckBox.ValueChangedFcn = createCallbackFcn(app, @ReversepolarityCheckBoxValueChanged, true);
            app.ReversepolarityCheckBox.Text = 'Reverse polarity';
            app.ReversepolarityCheckBox.Position = [43 1 109 22];
            app.ReversepolarityCheckBox.Value = true;

            % Create SignaltypeLabel
            app.SignaltypeLabel = uilabel(app.VoltageParametersPanel);
            app.SignaltypeLabel.HorizontalAlignment = 'right';
            app.SignaltypeLabel.Position = [9 64 39 28];
            app.SignaltypeLabel.Text = {'Signal'; 'type'};

            % Create SignaltypeDropDown
            app.SignaltypeDropDown = uidropdown(app.VoltageParametersPanel);
            app.SignaltypeDropDown.Items = {'Step', 'Ramped square', 'Triangle'};
            app.SignaltypeDropDown.ValueChangedFcn = createCallbackFcn(app, @SignaltypeDropDownValueChanged, true);
            app.SignaltypeDropDown.Position = [55 65 124 22];
            app.SignaltypeDropDown.Value = 'Step';

            % Create RampangleEditFieldLabel
            app.RampangleEditFieldLabel = uilabel(app.VoltageParametersPanel);
            app.RampangleEditFieldLabel.HorizontalAlignment = 'right';
            app.RampangleEditFieldLabel.Position = [38 38 70 22];
            app.RampangleEditFieldLabel.Text = 'Ramp angle';

            % Create RampangleEditField
            app.RampangleEditField = uieditfield(app.VoltageParametersPanel, 'numeric');
            app.RampangleEditField.Limits = [0 10000];
            app.RampangleEditField.ValueChangedFcn = createCallbackFcn(app, @RampangleEditFieldValueChanged, true);
            app.RampangleEditField.Position = [118 38 31 22];
            app.RampangleEditField.Value = 25;

            % Create kVsLabel
            app.kVsLabel = uilabel(app.VoltageParametersPanel);
            app.kVsLabel.Position = [151 38 29 22];
            app.kVsLabel.Text = 'kV/s';

            % Create CalibrationPanel
            app.CalibrationPanel = uipanel(app.UIFigure);
            app.CalibrationPanel.TitlePosition = 'centertop';
            app.CalibrationPanel.Title = 'Calibration';
            app.CalibrationPanel.FontWeight = 'bold';
            app.CalibrationPanel.FontSize = 14;
            app.CalibrationPanel.Position = [218 16 187 186];

            % Create SamplerateEditFieldLabel
            app.SamplerateEditFieldLabel = uilabel(app.CalibrationPanel);
            app.SamplerateEditFieldLabel.HorizontalAlignment = 'right';
            app.SamplerateEditFieldLabel.Position = [9 134 75 22];
            app.SamplerateEditFieldLabel.Text = 'Sample rate';

            % Create SamplerateEditField
            app.SamplerateEditField = uieditfield(app.CalibrationPanel, 'numeric');
            app.SamplerateEditField.Limits = [0 Inf];
            app.SamplerateEditField.ValueChangedFcn = createCallbackFcn(app, @SamplerateEditFieldValueChanged, true);
            app.SamplerateEditField.Position = [98 134 45 22];
            app.SamplerateEditField.Value = 1000;

            % Create HzLabel
            app.HzLabel = uilabel(app.CalibrationPanel);
            app.HzLabel.Position = [147 134 25 22];
            app.HzLabel.Text = 'Hz';

            % Create TREKvoltageconstantkVEditFieldLabel
            app.TREKvoltageconstantkVEditFieldLabel = uilabel(app.CalibrationPanel);
            app.TREKvoltageconstantkVEditFieldLabel.HorizontalAlignment = 'center';
            app.TREKvoltageconstantkVEditFieldLabel.Position = [9 94 79 27];
            app.TREKvoltageconstantkVEditFieldLabel.Text = {'TREK voltage'; 'constant (kV)'};

            % Create TREKvoltageconstantkVEditField
            app.TREKvoltageconstantkVEditField = uieditfield(app.CalibrationPanel, 'numeric');
            app.TREKvoltageconstantkVEditField.Limits = [0 Inf];
            app.TREKvoltageconstantkVEditField.ValueChangedFcn = createCallbackFcn(app, @TREKvoltageconstantkVEditFieldValueChanged, true);
            app.TREKvoltageconstantkVEditField.Editable = 'off';
            app.TREKvoltageconstantkVEditField.Position = [99 96 44 22];
            app.TREKvoltageconstantkVEditField.Value = 1;

            % Create VkVLabel
            app.VkVLabel = uilabel(app.CalibrationPanel);
            app.VkVLabel.Position = [147 96 31 22];
            app.VkVLabel.Text = 'V/kV';

            % Create MTforceconstantkFEditFieldLabel
            app.MTforceconstantkFEditFieldLabel = uilabel(app.CalibrationPanel);
            app.MTforceconstantkFEditFieldLabel.HorizontalAlignment = 'center';
            app.MTforceconstantkFEditFieldLabel.Position = [11 50 75 27];
            app.MTforceconstantkFEditFieldLabel.Text = {'MT force'; 'constant (kF)'};

            % Create MTforceconstantkFEditField
            app.MTforceconstantkFEditField = uieditfield(app.CalibrationPanel, 'numeric');
            app.MTforceconstantkFEditField.Limits = [0 Inf];
            app.MTforceconstantkFEditField.ValueChangedFcn = createCallbackFcn(app, @MTforceconstantkFEditFieldValueChanged, true);
            app.MTforceconstantkFEditField.Editable = 'off';
            app.MTforceconstantkFEditField.Position = [99 55 44 22];
            app.MTforceconstantkFEditField.Value = 9.96;

            % Create MTlengthconstantkLEditFieldLabel
            app.MTlengthconstantkLEditFieldLabel = uilabel(app.CalibrationPanel);
            app.MTlengthconstantkLEditFieldLabel.HorizontalAlignment = 'center';
            app.MTlengthconstantkLEditFieldLabel.Position = [9 11 75 27];
            app.MTlengthconstantkLEditFieldLabel.Text = {'MT length'; 'constant (kL)'};

            % Create MTlengthconstantkLEditField
            app.MTlengthconstantkLEditField = uieditfield(app.CalibrationPanel, 'numeric');
            app.MTlengthconstantkLEditField.Limits = [0 Inf];
            app.MTlengthconstantkLEditField.ValueChangedFcn = createCallbackFcn(app, @MTlengthconstantkLEditFieldValueChanged, true);
            app.MTlengthconstantkLEditField.Editable = 'off';
            app.MTlengthconstantkLEditField.Position = [99 13 45 22];
            app.MTlengthconstantkLEditField.Value = 1.93;

            % Create NVLabel
            app.NVLabel = uilabel(app.CalibrationPanel);
            app.NVLabel.Position = [147 55 26 22];
            app.NVLabel.Text = 'N/V';

            % Create mmVLabel
            app.mmVLabel = uilabel(app.CalibrationPanel);
            app.mmVLabel.Position = [147 12 37 22];
            app.mmVLabel.Text = 'mm/V';

            % Create ForceParametersPanel
            app.ForceParametersPanel = uipanel(app.UIFigure);
            app.ForceParametersPanel.TitlePosition = 'centertop';
            app.ForceParametersPanel.Title = 'Force Parameters';
            app.ForceParametersPanel.FontWeight = 'bold';
            app.ForceParametersPanel.FontSize = 14;
            app.ForceParametersPanel.Position = [612 16 187 186];

            % Create MaxforceEditFieldLabel
            app.MaxforceEditFieldLabel = uilabel(app.ForceParametersPanel);
            app.MaxforceEditFieldLabel.HorizontalAlignment = 'right';
            app.MaxforceEditFieldLabel.Position = [-5 134 104 22];
            app.MaxforceEditFieldLabel.Text = 'Max force';

            % Create MaxforceEditField
            app.MaxforceEditField = uieditfield(app.ForceParametersPanel, 'numeric');
            app.MaxforceEditField.Limits = [0 90];
            app.MaxforceEditField.ValueChangedFcn = createCallbackFcn(app, @MaxforceEditFieldValueChanged, true);
            app.MaxforceEditField.Position = [114 134 28 22];
            app.MaxforceEditField.Value = 30;

            % Create NLabel
            app.NLabel = uilabel(app.ForceParametersPanel);
            app.NLabel.Position = [148 134 25 22];
            app.NLabel.Text = 'N';

            % Create NumberofforcestepsLabel
            app.NumberofforcestepsLabel = uilabel(app.ForceParametersPanel);
            app.NumberofforcestepsLabel.HorizontalAlignment = 'right';
            app.NumberofforcestepsLabel.Position = [-32 93 131 28];
            app.NumberofforcestepsLabel.Text = {'Number of'; 'force steps'};

            % Create NumberofforcestepsEditField
            app.NumberofforcestepsEditField = uieditfield(app.ForceParametersPanel, 'numeric');
            app.NumberofforcestepsEditField.Limits = [1 Inf];
            app.NumberofforcestepsEditField.RoundFractionalValues = 'on';
            app.NumberofforcestepsEditField.ValueChangedFcn = createCallbackFcn(app, @NumberofforcestepsEditFieldValueChanged, true);
            app.NumberofforcestepsEditField.Position = [114 96 28 22];
            app.NumberofforcestepsEditField.Value = 16;

            % Create inclzeroLabel
            app.inclzeroLabel = uilabel(app.ForceParametersPanel);
            app.inclzeroLabel.HorizontalAlignment = 'center';
            app.inclzeroLabel.Position = [139 88 43 39];
            app.inclzeroLabel.Text = {'(incl.'; 'zero)'};

            % Create LogdistributionCheckBox
            app.LogdistributionCheckBox = uicheckbox(app.ForceParametersPanel);
            app.LogdistributionCheckBox.ValueChangedFcn = createCallbackFcn(app, @LogdistributionCheckBoxValueChanged, true);
            app.LogdistributionCheckBox.Text = 'Log distribution';
            app.LogdistributionCheckBox.Position = [42 13 103 22];

            % Create NumberofvoltcyclesperstepEditFieldLabel
            app.NumberofvoltcyclesperstepEditFieldLabel = uilabel(app.ForceParametersPanel);
            app.NumberofvoltcyclesperstepEditFieldLabel.HorizontalAlignment = 'right';
            app.NumberofvoltcyclesperstepEditFieldLabel.Position = [-37 52 142 28];
            app.NumberofvoltcyclesperstepEditFieldLabel.Text = {'Number of volt'; 'cycles per step'};

            % Create NumberofvoltcyclesperstepEditField
            app.NumberofvoltcyclesperstepEditField = uieditfield(app.ForceParametersPanel, 'numeric');
            app.NumberofvoltcyclesperstepEditField.Limits = [1 Inf];
            app.NumberofvoltcyclesperstepEditField.RoundFractionalValues = 'on';
            app.NumberofvoltcyclesperstepEditField.ValueChangedFcn = createCallbackFcn(app, @NumberofvoltcyclesperstepEditFieldValueChanged, true);
            app.NumberofvoltcyclesperstepEditField.Position = [114 55 28 22];
            app.NumberofvoltcyclesperstepEditField.Value = 4;

            % Create PressStopwhentestiscompletedtosavedataLabel
            app.PressStopwhentestiscompletedtosavedataLabel = uilabel(app.UIFigure);
            app.PressStopwhentestiscompletedtosavedataLabel.HorizontalAlignment = 'right';
            app.PressStopwhentestiscompletedtosavedataLabel.FontSize = 14;
            app.PressStopwhentestiscompletedtosavedataLabel.FontWeight = 'bold';
            app.PressStopwhentestiscompletedtosavedataLabel.Position = [464 256 137 50];
            app.PressStopwhentestiscompletedtosavedataLabel.Text = {'Press ''Stop'' when'; 'test is completed to'; 'save data'};

            % Create MonitorlimittripstatusCheckBox
            app.MonitorlimittripstatusCheckBox = uicheckbox(app.UIFigure);
            app.MonitorlimittripstatusCheckBox.ValueChangedFcn = createCallbackFcn(app, @MonitorlimittripstatusCheckBoxValueChanged, true);
            app.MonitorlimittripstatusCheckBox.Enable = 'off';
            app.MonitorlimittripstatusCheckBox.Text = 'Monitor limit/trip status';
            app.MonitorlimittripstatusCheckBox.Position = [645 220 142 22];

            % Create Lamp
            app.Lamp = uilamp(app.UIFigure);
            app.Lamp.Position = [618 220 20 20];

            % Create UIAxes
            app.UIAxes = uiaxes(app.UIFigure);
            title(app.UIAxes, 'Data')
            xlabel(app.UIAxes, 'Time (s)')
            ylabel(app.UIAxes, 'Voltage (kV)')
            app.UIAxes.PlotBoxAspectRatio = [1.45226130653266 1 1];
            app.UIAxes.Position = [54 208 404 278];

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = ForceControl_exported

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