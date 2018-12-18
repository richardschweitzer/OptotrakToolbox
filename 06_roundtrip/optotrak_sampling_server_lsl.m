%%%%%% THE OPTOTRAK SAMPLING SERVER %%%%%
% by Richard Schweitzer, 08/2016


file_name = 'demo_data_1.P01';  % specify the name of the buffer here
% add path to the Matlab_to_Optotrak.mexw32 mex-file
addpath('\\KASTORI\Users\sysop\Documents\Visual Studio 2015\Projects\Matlab_to_Optotrak\Debug') 
% add path to labstreamer library
addpath(genpath('C:\labstreaminglayer-master\LSL\liblsl-Matlab'));

% It is possible to break the sampling loop pressing the key below. 
% Only to be used in extreme cases, where the stop_code didn't work.
% IMPORTANT: Requires the installation of psychtoolbox!
stopkey = KbName('q'); 
check_for_stopkey_every = 150;  % how often should we check for the stopkey?
stopkey_received = 0;   % is set to 1 when stopkey has been received



%% LSL. Outlet and inlet specifications.
% outlet specifications. this is the stream that sends Optotrak data.
outlet_name = 'OptotrakStream';  % this is the name of the output stream in LSL
outlet_type = 'Optotrak';        % this is the type of data of the output stream
% inlet specifications. this is the stream which can be resolved to receive commands
inlet_name = 'ExperimentStream'; % here put in the name of the stream from the Experiment host
% request and stop codes
request_code = 0;
stop_code = 1;


%% optotrak collection settings
collection_num_markers_1 = 3;     		% number of markers on port 1
collection_num_markers_2 = 6;     		% number of markers on port 2
collection_frequency = 300;     		% Hz
collection_duration = 82;        		% duration of collection, unless there is no command to stop
cam_filename = 'Aligned20160728';     % alignment file for sensor (.cam)

external_clock_yes = 1;                 % to be set to 1, if external start of collection and clocking of frames via TTL is done

transform_requested = 0;                % indicate 1 here, if you want to sample rigid objects
start_marker_3d = 1;                    % when requesting transforms, from which marker on do we want to see 3d data
end_marker_3d = 9;   

total_frame_num = collection_frequency * collection_duration;
sample_length = 100; % how many values we'll have depends on several things, such as #markers, #rigids, etc.



%% loading and preallocation
retrieved_iterator = 0; % iterator for the sample
stop_code_received = 0; % this is set to 1 when stop_code has been received from client
terminate_collection = 0;  % this is set to 1 when Buffer spooling is complete. 
                           % That is either when DataBufferStop was called correctly or when the max collection duration has been reached
                           % -99 when DataBufferStop failed or -98 when the stopkey was pressed                         
sampling_success = 0;  % is 1 if sampling was concluded nicely
message_from_client = []; % this is the message from the the other side
i = 0;  % iterator for timing
% where we store sampling data and timing data
timing_values = NaN(1000000, 10);
latest_data = [];
retrieved_data = [];
shit_data = [];
o = 1;

%% setup the optotrak collection
optotrak_connection_success = 0;
try
    % setup routines for Optotrak
    [load_error, error_code] = Matlab_to_Optotrak('TransputerLoadSystem', ... 
            collection_num_markers_1, collection_num_markers_2, ...
            collection_frequency, collection_duration, cam_filename, external_clock_yes);
    if (load_error ~= 0)
        disp(error_code);
        error('TransputerLoadSystem died!');
    else
        disp(strcat(error_code, 'SUCCESS'));
    end
    
    %% load rigid bodies here, if transform_requested is not 0 %%
    if transform_requested ~= 0
        rigid_filename_0 = 'schrank_4';
        rigid_filename_1 = 'spinal_2';
        rigid_filename_2 = 'spinal_3';
        
        % load the shelf
        [a b] = Matlab_to_Optotrak('RigidBodyAddFromFile', 0, 1, rigid_filename_0);
        if (a ~= 0)
            error('RigidBodyAddFromFile did not work!');
        end
        
        % load the first rigid object
        [a b] = Matlab_to_Optotrak('RigidBodyAddFromFile', 1, 4, rigid_filename_1);
        if (a ~= 0)
            error('RigidBodyAddFromFile did not work!');
        end
        
        % load the second rigid object
        [a b] = Matlab_to_Optotrak('RigidBodyAddFromFile', 2, 7, rigid_filename_2);
        if (a ~= 0)
            error('RigidBodyAddFromFile did not work!');
            b
        end
    end
    %%
    
    % activate the markers already
    [activate_error, error_code] = Matlab_to_Optotrak('OptotrakActivateMarkers');
    if (activate_error ~= 0)
        disp(error_code);
        error('OptotrakActivateMarkers died!');
    else
        disp(strcat(error_code, 'SUCCESS'));
    end
    % setup buffer
    [setup_buffer_error, error_code] = Matlab_to_Optotrak('DataBufferInitializeFile', '', file_name);
    if (activate_error ~= 0)
        disp(error_code);
        error('DataBufferInitializeFile died!');
    else
        disp(strcat(error_code, 'SUCCESS'));
    end
    
    % retrieve a sample and preallocate, if there is no external triggering
    if ~external_clock_yes
        if transform_requested == 0 % request 3D or Transform data?
            [a, b] = Matlab_to_Optotrak('DataGetLatest3D');
        else
            [a, b] = Matlab_to_Optotrak('DataGetLatestTransforms');
        end
        % get length of sample
        if (a == 0)
            sample_length = length(b);
            disp(['Sample length = ' num2str(sample_length)]);
        end
        % preallocate
        retrieved_data = NaN(total_frame_num, sample_length);
        latest_data = NaN(1, sample_length);
    end
    
    % if we're here, then setup was successful
    if load_error == 0 && activate_error == 0 && setup_buffer_error == 0
        optotrak_connection_success = 1;
    end
catch ME
    rethrow(ME);
end



%% connect server and client via LSL
if optotrak_connection_success
    try
        %% instantiate LSL
        disp('Loading library...');
        lib = lsl_loadlib();
        
        % make a new stream outlet. Optotrak Host -> Experiment Host
        disp('Creating stream info for the Optotrak');
        info = lsl_streaminfo(lib, outlet_name, outlet_type, sample_length,...
                    collection_frequency,'cf_float32','myuniquesourceid1');
        disp('Opening the Optotrak outlet...');
        outlet = lsl_outlet(info);
        disp('Done.');
        
        % make a stream inlet. Experiment Host -> Optotrak Host
        % resolve a stream...
        disp('Now trying to resolve the stream from the Experiment Host...');
        result = {};
        while isempty(result)
            result = lsl_resolve_byprop(lib,'name',inlet_name); 
        end
        % create a new inlet
        disp('Opening an inlet...');
        inlet = lsl_inlet(result{1});
        disp('Done.');
        
        server_client_connected = 1;
        
    catch ME
        server_client_connected = 0;
        display(ME);
    end 
end



%% start sampling
if optotrak_connection_success && server_client_connected
    disp('Sampling section begins now!');
    
    try
        % start Buffer.
        % Initialize sampling only, if Buffer is started correctly
        [buffer_start_error, error_code] = Matlab_to_Optotrak('DataBufferStart');
        if (buffer_start_error ~= 0)
            disp(error_code);
            error('DataBufferStart did not work! Exiting now!');
        else % buffer started. Good, now let's start sampling!
            disp('DataBufferStart success!');
            
            %%%% SAMPLING STARTS HERE! %%%%
            % request a first sample!
            if transform_requested == 0 % request 3D or Transform data?
                Matlab_to_Optotrak('RequestLatest3D');
            else
                Matlab_to_Optotrak('RequestLatestTransforms');
            end
            
            % SAMPLE and wait for requests as long as there is no command to
            % stop or until the Buffer is stopped!
            disp('Now sampling..........');
            while terminate_collection == 0
                i = i+1;
                tic;
                % check whether Data is available!
                if transform_requested == 0 % request 3D or Transform data?
                    % 3D data
                    [data_status, data, ts, te] = Matlab_to_Optotrak('DataReceiveLatest3D');
                else
                    % Transform data
                    [data_status, data, ts, te] = Matlab_to_Optotrak('DataReceiveLatestTransforms', ...
                                                                start_marker_3d, end_marker_3d);
                end
                timing_values(i,9) = (te - ts) / 1000; % all the other values are in s, te and ts are in ms
                timing_values(i,1) = toc;
                % find out whats wrong
                if timing_values(i,1) > 0.04
                    disp(data);
                    %shit_data(o,:) = [data_status, data, ts, te];
                    o = o +1;
                end    
                % if data was returned and is valid, then and only then ...
                tic;
                if data_status ~= -1 && strcmp(data, 'DataNotReady') ~= 1
                    retrieved_iterator = retrieved_iterator + 1;
                    % update latest_data
                    latest_data = data;
                    retrieved_data(retrieved_iterator,:) = latest_data;
                    % write to LSL outlet. JUST THIS ONE LINE!!!==!"§
                    outlet.push_sample([latest_data, NaN( 1, sample_length-length(latest_data))]);
                    % write to buffer. Emptying the buffer is prerequisite for
                    % the termination of the loop!
                    [buffer_write_error, spool_complete] = Matlab_to_Optotrak('DataBufferWriteData');
                    if (buffer_write_error ~= 0)
                        disp('Warning: DataBufferWriteData did not work!');
                    end
                    if (spool_complete ~= 0) % this would mean that we have reached the max collection duration
                        disp('Buffer spooling has finished or was stopped.');
                        terminate_collection = 1;
                        sampling_success = Matlab_to_Optotrak('OptotrakStopCollection') == 0;
                    end
                    % request next sample, if there is no command to terminate the collection
                    if terminate_collection == 0
                        % request 3D or Transform data?
                        if transform_requested == 0
                            [~, ~, ts2, te2] = Matlab_to_Optotrak('RequestNext3D');
                            %[~, ~, ts2, te2] = Matlab_to_Optotrak('RequestLatest3D'); % or request latest 3D
                        else
                            [~, ~, ts2, te2] = Matlab_to_Optotrak('RequestNextTransforms');
                            %[~, ~, ts2, te2] = Matlab_to_Optotrak('RequestLatestTransforms'); % or request latest Transform
                        end
                        timing_values(i,10) = (te2 - ts2) / 1000;
                    end
%                 else
%                     % try a delay here
%                     delay(0.001);
                end
                timing_values(i,4) = retrieved_iterator;
                if ~isempty(latest_data)
                    timing_values(i,3) = latest_data(1);
                else
                    timing_values(i,3) = 0;
                end
                timing_values(i,2) = toc;
                % Check whether there's a request on the stream:
                % If there is smth in the input stream from client to server and
                % there has been no stop_code received from the client, then read it.
                tic;
                message_from_client = inlet.pull_chunk();
                % read the message if there is one
                if ~isempty(message_from_client) && stop_code_received == 0 && ~isempty(latest_data)
%                     disp(strcat('Message from client: ', char(message_from_client)));
                    stop_code_received = any(message_from_client == stop_code);
                    if stop_code_received % if there is the command to stop in the retrieved chuck
                        % ... then tell the optotrak to stop buffering. In that
                        % case, DataBufferWriteData will return spool_complete non-zero
                        % in the next (and last) frame is retreived and subsequently
                        % terminate_collection will be set to 1
                        disp('Stop code received!');
                        [buffer_stop_error, error_code] = Matlab_to_Optotrak('DataBufferStop');
                        if (buffer_stop_error ~= 0)
                            disp(error_code);
                            disp('DataBufferStop died! This might result in a corrupted Buffer File!');
                            terminate_collection = -99;
                        else % buffer stopped nicely
                            disp('DataBufferStop success!');
                        end
                   end
                end % end of reading message from client
                timing_values(i,6) = stop_code_received;
                timing_values(i,5) = toc;
                % Now check whether a keypress has been done. If one
                % presses the stopkey, then the loop should break. However,
                % KbCheck is rather slow, this is why we enter this loop
                % only, if the iterator i is divisible by 150.
                tic;
                if mod(i, check_for_stopkey_every) == 0
                    [keyIsDown, secs, keyCode] = KbCheck;
                    if keyCode(stopkey) % the key is our stop key
                        disp('Stop key received! Exiting Now!');
                        stopkey_received = 1;
                        % stop buffer
                        [buffer_stop_error, error_code] = Matlab_to_Optotrak('DataBufferStop');
                        if (buffer_stop_error ~= 0)
                            disp(error_code);
                            disp('DataBufferStop died! This might result in a corrupted Buffer File!');
                        else % buffer stopped nicely
                            disp('DataBufferStop success!');
                        end
                        % stop collection
                        [collection_stop_error, error_code] = Matlab_to_Optotrak('OptotrakStopCollection');
                        if (collection_stop_error ~= 0)
                            disp(error_code);
                            disp('OptotrakStopCollection died!');
                        else % buffer stopped nicely
                            disp('OptotrakStopCollection success!');
                        end
                        % terminate the loop
                        terminate_collection = -98;
                        sampling_success = buffer_stop_error == 0 && collection_stop_error == 0;
                    end
                end
                timing_values(i,8) = stopkey_received;
                timing_values(i,7) = toc;
            end % end of sampling loop
        end % end of control that buffer started nicely
    catch error_in_sampling_loop % catch any error in the sampling loop
        disp('Encountered an error in the main sampling loop:');
        disp(error_in_sampling_loop);
    end
end % end of sampling section


%% buffer save and convert routines
% do this only if everything went well so far...
if optotrak_connection_success && server_client_connected && sampling_success
    disp('Now calling FileConvert.');
    % convert raw data to 3d data
    [file_convert_error, error_code] = Matlab_to_Optotrak('FileConvert', '', file_name);
    if (file_convert_error ~= 0)
        disp('FileConvert did not work! Convert the RAW data in a different way.');
    else
        disp(strcat('SUCCESS:', error_code));
    end
    % read into matlab!
    buffered_data = open_ndi_bin_file(strcat('C#', file_name));
    
end


%% shutdown routines
% deactivate Markers
[deactivate_error, error_code] = Matlab_to_Optotrak('OptotrakDeActivateMarkers');
if (deactivate_error ~= 0)
    disp(error_code);
    disp('Warning: OptotrakDeActivateMarkers did NOT work nicely!');
else
    disp('Optotrak Markers nicely deactivated!');
end
% shutdown transputer
[shutdown_error, error_code] = Matlab_to_Optotrak('TransputerShutdownSystem');
if (shutdown_error ~= 0)
    disp(error_code);
    disp('Warning: TransputerShutdownSystem did NOT work nicely!');
else
    disp('Optotrak shut down nicely!');
end
% shutdown outlets and inlets
inlet.close_stream;
outlet.delete;


%% PLOT stuff %%
disp('Now producing plot...');
figure(1234);
subplot(7,1,1);
plot(timing_values(:, 1), '.');
title('Time for Checking and Receiving');
subplot(7,1,2);
plot(timing_values(:, 2), '.');
title('Time for Spooling, Sending via LSL and Requesting new Sample');
subplot(7,1,3);
plot(timing_values(:, 5), '.');
title('Time for Reading via LSL');
subplot(7,1,4);
plot(timing_values(:, 7), '.');
title('Time for Checking Keyboard Press');
subplot(7,1,5);
plot(timing_values(:, 1)+timing_values(:, 2)+timing_values(:, 5)+timing_values(:, 7), '.');
title('Time for whole Loop');
subplot(7,1,6);
plot(timing_values(:, 9), '.');
title('C time for Checking and Receiving');
subplot(7,1,7);
plot(timing_values(:, 10), '.');
title('C time for Spooling, Sending via LSL and Requesting new Sample');
disp('Done.');
