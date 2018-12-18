%%%%%% THE OPTOTRAK SAMPLING SERVER %%%%%
% by Richard Schweitzer, 08/2016


file_name = 'demo_data_1.P01';  % specify the name of the buffer here
% add path to the Matlab_to_Optotrak.mexw32 mex-file
addpath('\\KASTORI\Users\sysop\Documents\Visual Studio 2015\Projects\Matlab_to_Optotrak\Debug') 

% It is possible to break the sampling loop pressing the key below. 
% Only to be used in extreme cases, where the stop_code didn't work.
% IMPORTANT: Requires the installation of psychtoolbox!
stopkey = KbName('q'); 
check_for_stopkey_every = 150;  % how often should we check for the stopkey?
stopkey_received = 0;   % is set to 1 when stopkey has been received



%% server and client specifications. This is the server!
number_of_retries = 10;
stop_code = 'stopCollection'; % the code to stop the collection and to shutdown
request_code = 'request';   % the code if latest value is request
default_code = 'none';      % the code if no request has been received
% server data. 
this_ip = '172.29.7.127'; % this value is not used. it's for info only
output_port_server = 2016; % the output port of the server must be the input port of the client
server_socket  = [];
output_socket_server  = [];
% client data
client_ip = '172.29.10.15';
input_port_server = 2015; % the input port of the server must be the output port of the client
input_socket_server  = [];



%% optotrak collection settings
collection_num_markers_1 = 3;     		% number of markers on port 1
collection_num_markers_2 = 6;     		% number of markers on port 2
collection_frequency = 130;     		% Hz
collection_duration = 35;        		% duration of collection, unless there is no command to stop
cam_filename = 'Aligned20160728';     % alignment file for sensor (.cam)

external_clock_yes = 1;                 % to be set to 1, if external start of collection and clocking of frames via TTL is done

transform_requested = 0;                % indicate 1 here, if you want to sample rigid objects
start_marker_3d = 1;                    % when requesting transforms, from which marker on do we want to see 3d data
end_marker_3d = 9;   

total_frame_num = collection_frequency * collection_duration;
sample_length = 100; % how many values we'll have depends on several things, such as #markers, #rigids, etc.



%% loading and preallocation
import java.net.ServerSocket
import java.net.Socket
import java.io.*

retrieved_iterator = 0; % iterator for the sample
stop_code_received = 0; % this is set to 1 when stop_code has been received from client
terminate_collection = 0;  % this is set to 1 when Buffer spooling is complete. 
                           % That is either when DataBufferStop was called correctly or when the max collection duration has been reached
                           % -99 when DataBufferStop failed or -98 when the stopkey was pressed                         
sampling_success = 0;  % is 1 if sampling was concluded nicely
message_from_client = default_code; % this string is the message from the client
i = 0;  % iterator for timing

% where we store sampling data and timing data
timing_values = [];
latest_data = [];
retrieved_data = []; 
%retrieved_data = zeros(total_frame_num, sample_length); % preallocate only, if sample_length is known




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
    [activate_error, error_code] = Matlab_to_Optotrak('OptotrakActivateMarkers'); %#ok<NASGU>
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
    
    % if we're here, then setup was successful
    if load_error == 0 && activate_error == 0 && setup_buffer_error == 0
        optotrak_connection_success = 1;
    end
catch ME
    rethrow(ME);
end



%% connect server and client via TCP
% based on: http://iheartmatlab.blogspot.de/2008/08/tcpip-socket-communications-in-matlab.html
if optotrak_connection_success
    retry = 0;
    connected_output = 0;
    connected_input = 0;
    % start trying to connect
    while connected_output == 0 || connected_input == 0
        retry = retry + 1;
        % break when there are
        if ((number_of_retries > 0) && (retry > number_of_retries))
            fprintf(1, 'Too many retries\n');
            break;
        end
        try
            %% setup output stream from server to client (we are the server)
            if connected_output == 0
                fprintf(1, ['Try %d waiting for client to connect to this ' ...
                    'server on port : %d\n'], retry, output_port_server);
                % wait for 1 second for client to connect server socket
                server_socket = ServerSocket(output_port_server);
                server_socket.setSoTimeout(1000);
                % make output socket when server socket is accepted by client
                output_socket_server = server_socket.accept;
                fprintf(1, 'Output Connection established on Server: Server to Client\n');
                % make outputStream
                output_stream_server   = output_socket_server.getOutputStream;
                d_output_stream_server = DataOutputStream(output_stream_server);
                % outputStream created
                connected_output = 1;
            end
            %% setup input stream from client to server (we are the server)
            if connected_input == 0
                fprintf(1, 'Retry %d connecting to client %s:%d\n', ...
                    retry, client_ip, input_port_server);
                % throws if unable to connect
                input_socket_server = Socket(client_ip, input_port_server);
                input_socket_server.setTcpNoDelay(1);
                % get a buffered data input stream from the socket
                input_stream_server = input_socket_server.getInputStream; 
                d_input_stream_server = DataInputStream(input_stream_server);
                %
                fprintf(1, 'Input Connection established on Server: Client to Server\n');
                connected_input = 1;
            end
        catch %ME
            if ~isempty(server_socket) && connected_output == 0
                server_socket.close
            end
            if ~isempty(output_socket_server) && connected_output == 0
                output_socket_server.close
            end
            if ~isempty(input_socket_server) && connected_input == 0
                input_socket_server.close
            end
            % pause before retrying
            pause(1);
            %rethrow(ME);
        end
    end
    server_client_connected = connected_output == 1 && connected_input == 1;
    if server_client_connected
        disp('Server and Client now bilaterally connected.');
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
                    [data_status, data] = Matlab_to_Optotrak('DataReceiveLatest3D');
                else
                    % Transform data
                    [data_status, data] = Matlab_to_Optotrak('DataReceiveLatestTransforms', ...
                                                                start_marker_3d, end_marker_3d);
                end
                timing_values(i,1) = toc;
                % if data was returned and is valid, then and only then ...
                tic;
                if data_status ~= -1 && strcmp(data, 'DataNotReady') ~= 1
                    retrieved_iterator = retrieved_iterator + 1;
                    % update latest_data
                    latest_data = data;
                    retrieved_data(retrieved_iterator,:) = latest_data;
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
                            Matlab_to_Optotrak('RequestNext3D');
                            %Matlab_to_Optotrak('RequestLatest3D'); % or request latest 3D
                        else
                            Matlab_to_Optotrak('RequestNextTransforms');
                            %Matlab_to_Optotrak('RequestLatestTransforms'); % or request latest Transform
                        end
                    end
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
                bytes_available = input_stream_server.available;
                if bytes_available > 0 && stop_code_received == 0 && ~isempty(latest_data)
                    % what's the UTF message from the client?
                    message_from_client = char( d_input_stream_server.readUTF );
%                     disp(strcat('Message from client: ', char(message_from_client)));
                    if strcmp(message_from_client, request_code)  % if message is a request
                        message_to_client = strcat('[', sprintf('%d ', latest_data), ']'); % this one's faster
                        d_output_stream_server.writeUTF(message_to_client); % then send the latest data
%                         disp(strcat('Answer from server: ', char(message_to_client)));
                        d_output_stream_server.flush;
%                         disp(latest_data);
                        message_from_client = default_code; % set message to default
                    elseif strcmp(message_from_client, stop_code) % if message is the command to stop
                        % ... then tell the optotrak to stop buffering. In that
                        % case, DataBufferWriteData will return spool_complete non-zero
                        % in the next (and last) frame is retreived and subsequently
                        % terminate_collection will be set to 1
                        stop_code_received = 1;
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
                timing_values(i,6) = bytes_available;
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
% shutdown LAN connections
if ~isempty(server_socket)
    server_socket.close
end
if ~isempty(output_socket_server)
    output_socket_server.close
end
if ~isempty(input_socket_server)
    input_socket_server.close
end


%% PLOT stuff %%
disp('Now producing plot...');
figure(1234);
subplot(5,1,1);
plot(timing_values(:, 1), '.');
title('Time for Checking and Receiving');
subplot(5,1,2);
plot(timing_values(:, 2), '.');
title('Time for Buffering and Requesting new Sample');
subplot(5,1,3);
plot(timing_values(:, 5), '.');
title('Time for Reading and Writing via TCP');
subplot(5,1,4);
plot(timing_values(:, 7), '.');
title('Time for Checking Keyboard Press');
subplot(5,1,5);
plot(timing_values(:, 1)+timing_values(:, 2)+timing_values(:, 5)+timing_values(:, 7), '.');
title('Time for whole Loop');
disp('Done.');
