% collects some data as produced by LSL_test_for_sven.m
% FOR SVEN!
% by richard 06/2018

% inlet specifications. must be what we specified in the other file
inlet_name = 'SvensStream';  % this is the name of the input stream in LSL
inlet_type = 'Sven';        % this is the type of data of the input stream
timeout = 4;            % when to stop if nothing happens (in seconds)

% add path to LSL:
addpath(genpath('/home/richard/Dropbox/PROMOTION WORKING FOLDER/General/LSL/labstreaminglayer-master/LSL/liblsl-Matlab'));

% load library
disp('Loading library...');
lib = lsl_loadlib();

% now open this very stream as an inlet.
disp('Now trying to resolve the stream...');
result = {};
started_resolving = GetSecs;
while (GetSecs - started_resolving) < timeout && ...
        isempty(result) 
    result = lsl_resolve_byprop(lib,'name',inlet_name);
end
pause(0.5);

% Make an inlet if the stream was found...
if ~isempty(result) 
    disp('Found the stream!');
    % create a new inlet
    disp('Now opening an inlet...');
    inlet = lsl_inlet(result{1});
    disp('Done.');
    pause(0.1)
    
    % now sample from stream...
    timestamps = [];
    break_out = 0;
    while break_out == 0 && ~KbCheck
        what_was_sent = [];
        started_sampling = GetSecs;
        % wait for sample, unless timeout:
        while (GetSecs - started_sampling) < timeout && ...
                isempty(what_was_sent) % try until we get something
            [what_was_sent, ts] = inlet.pull_sample();
            disp(['Timestamp: ', num2str(ts)]);
            disp('Data:');
            disp(what_was_sent);
            timestamps = [timestamps, ts]; % can't be preallocated
        end
        % break if nothing was collected for some time
        if isempty(what_was_sent)
            break_out = 1;
        end
    end
    
    % sampling finished: close stream
    inlet.close_stream;
    if ~isempty(timestamps) && length(timestamps)>=2
        histogram(diff(timestamps));
        title('Time between timestamps');
    end
else
    disp('Timeout. Could not resolve stream.')
end
