%% the great roundtrip: qumisha - datapixx - (TTL) - optotrak - kastori - (TCP) - qumisha %%
% by richard 08/2016

% This demo will attempt a motion-contingent presentation on the propixx.
% These are the steps:
% 0. start a prepared collection on kastori via a TTL (serial pin 7) to the
% optotrak SCU
% 1. setup a DoutSchedule on the Datapixx and sync it with the first frame
% refresh. This will lead to a production of an optotrak sample and its
% registration by kastori
% 2. request the sample from kastori via TCP
% 3. display the position of a marker in the screen


%% predefine some values here 
seconds = 25;    % for how many seconds to we want the main loop to run?
start_trigger_pin = 2^6; % serial pin 7 goes to parallel pin 4, which is digital out 6
clock_trigger_pin = 2^2; % serial pin 3 goes to parallel pin 2, which is digital out 2
scale_factor = 100; % the larger this value, the higher the frequency with which a DoutWave is sent.
                    % if we have 120 Hz, then scale_factor=100 makes 12000 Hz, thus producing a clock trigger of 0.0833 ms
excess_fire = 1000;  % one should have a certain number of excess pulses, so that the server finishes nicely
bufferAddress = 8e6; % this is the address of the digital out buffer of datapixx
f = 0;       % frame iterator
request_code = 'request'; % write this to stream in order to request a sample
stop_code = 'stopCollection'; % write this to stop the Collection on the server


%% setup TCP connection to kastori
tic;
disp('Setting up TCP to server (kastori).');
% this is the command to set up the connection to kastori. Insert the
% right parameters (ip, port_in, port_out) in accordance with the server.
[in_socket, in_stream, d_in_stream, client_socket, out_socket, out_stream, d_out_stream] = ...
    connect_to_optotrak_sampling_server(50, 2016, '172.29.7.127', 2015);
% abort the script if the connection failed
if isempty(in_socket) || isempty(client_socket) || isempty(out_socket)
    error('Error while connecting to optotrak server! Aborting now!');
end
toc;

%% setup datapixx
tic;
disp('Setting up Datapixx and all TTL digital outputs to low.');
startDatapixx;
toc;

%% setup the psychtoolbox screen
tic;
disp('Setting up psychtoolbox screen.');
AssertOpenGL;   
screens = Screen('Screens');
screenNumber = max(screens);
% Define black, white and grey
black = BlackIndex(screenNumber);
white = WhiteIndex(screenNumber);
grey = white / 2;
% Open an on screen window and color it grey
[window, windowRect] = PsychImaging('OpenWindow', screenNumber, grey);
refresh_rate = Screen(window, 'FrameRate'); % get refresh rate
% Draw first frame
DrawFormattedText(window, 'Screen created.', 'center', 'center', white);
Screen('Flip', window);
toc;

%% setup the datapixx routine to start the prepared collection of samples, 
%% then shoot a TTL trigger on serial port 7 to start the collection on the first frame
% first, define a dOutWave to start the collection

try
    tic;
    disp('Setting up Datapixx routine to start collection of samples.');
    doutWave_start = [start_trigger_pin, 0]; % we just need one pulse on digital out 6, then set to 0
    Datapixx('WriteDoutBuffer', doutWave_start, bufferAddress);
    % here we define the schedule. we want doutWave_start to be executed only
    % once and that for let's say 1ms
    start_trigger_dur = 0.001;
    Datapixx('SetDoutSchedule', 0, [start_trigger_dur, 3], size(doutWave_start,2), bufferAddress);
    toc;
    % prepare the trigger to start the optotrak collection on next refresh
    tic;
    disp('Prepare output sequence for next frame refresh.');
    Datapixx('StartDoutSchedule');
    Datapixx('RegWrVideoSync');
    % refresh and thereby start the collection
    DrawFormattedText(window, 'Collection started!', 'center', 'center', white);
    vbl_collection_start = Screen('Flip', window); % start of collection should be triggered here
    toc;
catch start_trigger_error
    % close TCP connections
    d_out_stream.writeUTF(stop_code); % send request to terminate the sampling
    out_socket.close;
    in_socket.close;
    client_socket.close;
    % shutdown datapixx and screen
    shutdownDatapixx;
    sca;
    % rethrow the error, terminate script
    rethrow(start_trigger_error);
end
    
%% setup the datapixx routine to clock samples during the main roundtrip loop
try
    tic;
    disp('Prepare output sequence to clock samples and sync it to next refresh');
    % first, we have to create a signal, that is composed of individual samples (on/off)
    % ideally, we want a very short on signal. Here we define 1/100 of whatever timescale.
    doutWave_clock = [clock_trigger_pin, zeros(1,99)];
    Datapixx('WriteDoutBuffer', doutWave_clock, bufferAddress);
    % now schedule the output sequence...
    samplingRate = refresh_rate*scale_factor;      % the frequency at which we shoot on/off signals
    samplesPerFrame = size(doutWave_clock,2);      % how many samples have we defined in the doutWave?
    framesPerTrial = refresh_rate * seconds + excess_fire;       % we'll send triggers for every video frame.
    samplesPerTrial = samplesPerFrame * framesPerTrial;  % that's the total number of signals we will be sending
    % okay, now we have all the info we need to schedule the output sequence:
    % [samplingRate, 1] means we'll shoot samples at the defined sampling freq
    % samplesPerTrial is the total number of samples we'll send
    Datapixx('SetDoutSchedule', 0, [samplingRate, 1], samplesPerTrial, bufferAddress, samplesPerFrame);
    % finally, sync this schedule with the next refresh, that is in the main loop
    Datapixx('StartDoutSchedule');
    PsychDataPixx('RequestPsyncedUpdate') % Mario Kleiner proposed this
    Datapixx('RegWrVideoSync');
    toc;
catch clock_trigger_error
    % close TCP connections
    d_out_stream.writeUTF(stop_code); % send request to terminate the sampling
    out_socket.close;
    in_socket.close;
    client_socket.close;
    % shutdown datapixx and screen
    shutdownDatapixx;
    sca;
    % rethrow the error, terminate script
    rethrow(clock_trigger_error);
end


%% main loop: refresh - clock sample - request sample from kastori - display sample
disp('Starting main loop');
% preallocate
x_pos = 300;
y_pos = 300;
z_pos = 0;
vbl_times = zeros(framesPerTrial-excess_fire, 1);
loop_times = zeros(framesPerTrial-excess_fire, 5);
decode_times = [];
positions = []; %zeros(framesPerTrial, 3);
samples = [];

% start the loop, where the main action is happening
try
    start_tic = tic;
    for f = 1:(framesPerTrial-excess_fire)
        loop_tic = tic;
        % draw dot at position
        Screen('Drawdots', window, [x_pos, y_pos], 10, white);
        if ~isempty(positions)
            Screen('Drawdots', window, [positions(1, :); positions(2, :)], 10, black);
        end
        vbl_times(f) = Screen('Flip', window); % this should trigger a sample
        loop_times(f, 1) = toc(loop_tic); % time elapsed until screen flip
        % request optotrak sample from kastori
        try
            d_out_stream.writeUTF(request_code); % request a sample
        catch
            error('Request code could not be sent via OutStream');
        end
        loop_times(f, 2) = toc(loop_tic)-loop_times(f,1); % time elapsed until request sent
        % wait for optotrak sample to return and decode it as soon as it arrives
        data_available = 0;
        data_available_tic = tic;
        while ~data_available
            [data_available, sample_data, bytes, dur1, dur2, dur3] = receive_from_optotrak_sampling_server(in_stream, d_in_stream);
            if data_available
                decode_times(f, :) = [dur1 dur2 dur3];
            end
            if toc(data_available_tic)>5 % abort when there has been no sample within 1 second
                error('No sample was returned within 5 seconds. Exciting now!');
            end
        end
        loop_times(f, 5) = bytes;
        loop_times(f, 3) = toc(loop_tic)-loop_times(f, 2)-loop_times(f,1); % time elapsed until sample is received
        % save sample and choose position values to present
        samples(f,:) = sample_data;
        % 22-24
        x_pos = abs(sample_data(22))*2;
        y_pos = abs(sample_data(23))*2;
        z_pos = sample_data(24);
        positions(:, f) = [x_pos, y_pos, z_pos];
        loop_times(f, 4) = toc(loop_tic)-loop_times(f, 3)-loop_times(f, 2)-loop_times(f,1); % time elapsed until loop is complete
    end
    d_out_stream.writeUTF(stop_code); % send request to terminate the sampling
catch main_loop_error
    % close TCP connections
    out_socket.close;
    in_socket.close;
    client_socket.close;
    % shutdown datapixx and screen
    sca;
    shutdownDatapixx;
    % rethrow the error, terminate script
    rethrow(main_loop_error);
end


%% shutdown screen and datapixx
pause(2);
disp('Demo has ended!');
sca;
% Shutdown Datapixx
shutdownDatapixx;

%% shutdown connection to kastori
if ~isempty(in_socket)
    in_socket.close;
end
if ~isempty(out_socket)
    d_out_stream.writeUTF(stop_code); % request to terminate the sampling
    out_socket.close;
end
if ~isempty(client_socket)
    client_socket.close;
end

% compute durations between VBLs
vbl_diff = zeros(1, length(vbl_times)-1);
for i = 1:(length(vbl_times)-1)
    vbl_diff(i) = vbl_times(i+1)-vbl_times(i);
end
 
%% print out some timing values
% loop times
figure(1234);
subplot(1,5,1);
plot(loop_times(:, 2), '.');
title('Request Duration');
subplot(1,5,2);
plot(loop_times(:, 3), '.');
title('Time from Request to Receive');
subplot(1,5,3);
plot(loop_times(:, 4), '.');
title('Time for Saving Data');
subplot(1,5,4);
plot(loop_times(:, 1), '.');
title('Time to next refresh');
subplot(1,5,5);
plot(vbl_diff, '.');
title('Time between VBLs');

% decode times
figure(1235);
subplot(1,3,1);
plot(decode_times(:, 1), '.');
title('time to read UTF');
subplot(1,3,2);
plot(decode_times(:, 2), '.');
title('time to split string');
subplot(1,3,3);
plot(decode_times(:, 3), '.');
title('time to convert strings to double');