% test LSL on one computer... (needs psychtoolbox)
% FOR SVEN!
% by richard, 06/2018

% add path to LSL:
addpath(genpath('/home/richard/Dropbox/PROMOTION WORKING FOLDER/General/LSL/labstreaminglayer-master/LSL/liblsl-Matlab'));

% load library
disp('Loading library...');
lib = lsl_loadlib();

% outlet specifications. this is the stream that sends data to any interested host.
outlet_name = 'SvensStream';  % this is the name of the output stream in LSL
outlet_type = 'Sven';        % this is the type of data of the output stream
sample_length = 10;         % dimensions of the data, e.g., 10x10
collection_frequency = 2; % samples per second
max_runs = 1000;   % how many maximum timing runs?

% make a new stream outlet.
disp('Creating stream info for the stream');
info = lsl_streaminfo(lib, outlet_name, outlet_type, sample_length,...
    collection_frequency,'cf_float32','myuniquesourceid2');
disp('Opening the outlet...');
outlet = lsl_outlet(info);
disp('Done.');
pause(1);

% now open this very stream as an inlet.
disp('Now resolving the stream we just created...');
result = {};
inlet_name = outlet_name;
while isempty(result)
    result = lsl_resolve_byprop(lib,'name',inlet_name);
end
% create a new inlet
disp('Opening an inlet...');
inlet = lsl_inlet(result{1});
disp('Done.');

% now send some data to the stream.
disp('Now try transmitting some chunked data to the outlet...');
pause(0.5);
KbReleaseWait;
% preparing the stream by sending something (what follows is most likely a bug)
outlet.push_sample(randn(1, 10)); 
probably_empty = inlet.pull_chunk();
pause(0.1);
outlet.push_sample(randn(1, 10)); 
probably_not_empty = inlet.pull_sample();
pause(0.1);
disp('Bug replicated?');
disp(isempty(probably_empty) && ~isempty(probably_not_empty));
pause(1);

% time stuff here...
disp('Timing the process...');
pause(0.5);
KbReleaseWait;
float_precision = 3; % what float precision?
i = 0;
latencies = NaN(1,max_runs);
while i < max_runs && ~KbCheck
    WaitSecs(1/collection_frequency); % simulates a sampling process
    i = i + 1;
    what_to_send = [i, randn(1, sample_length-1)]; % this is your data
    what_was_sent = [];
    % send here...
    outlet.push_sample(what_to_send); % stuff is sent here
    pushed = GetSecs; % timestamp for having sent stuff
    % receive here...
    while isempty(what_was_sent) % sample until we get something
        what_was_sent = inlet.pull_sample();
    end
    received = GetSecs; 
    % compute latency
    latencies(i) = (received-pushed)*1000;
    disp(['Sample ', num2str(i), ' received with ', num2str(latencies(i)), ' ms latency']);
    % check whether the matrices match:
    if all(all(round(what_to_send, float_precision)==round(what_was_sent, float_precision)))
        disp('Samples match.');
    else
        disp('Samples do not match.');
        disp(what_to_send)
        disp(what_was_sent)
    end
end

% shutdown outlets and inlets
inlet.close_stream;
outlet.delete;
disp('Demo completed')

% plot latencies:
histogram(latencies(~isnan(latencies)), 'BinWidth', 0.1);
title('Latencies [ms]')

