% test the new non-blocking routine
addpath('\\KASTORI\Users\sysop\Documents\Visual Studio 2015\Projects\Matlab_to_Optotrak\Debug')    

%clear all;
 
collection_num_markers_1 = 3;     		% number of markers on port 1
collection_num_markers_2 = 6;     		% number of markers on port 2
collection_frequency = 200;     		% Hz
collection_duration = 6;        		% s
collection_duration_loop = 2;
%cam_filename = 'Aligned20160704_1';     % .cam file for sensor. % name of sensor: C3-04864
%cam_filename = 'Aligned20160727';
cam_filename = 'Aligned20160728';

total_frame_num = collection_frequency * collection_duration_loop;

% setup routines for Optotrak
[a b] = Matlab_to_Optotrak('TransputerLoadSystem', collection_num_markers_1, collection_num_markers_2, ...
                collection_frequency, collection_duration, cam_filename, 0);	
if (a ~= 0)
    error('TransputerLoadSystem died!');
    b
end


[a b] = Matlab_to_Optotrak('OptotrakActivateMarkers'); %#ok<NASGU>
if (a ~= 0)
    error('OptotrakActivateMarkers died!');
    b
end

pause(2);

% get a test sample
[a, b] = Matlab_to_Optotrak('DataGetLatest3D');
b
sample_length = length(b);

% let's not write into a buffer, but just sample in matlab
save_here = zeros(total_frame_num, sample_length);
time_save_here = zeros(4, total_frame_num);
i = 1;
t = 1;

pause(1);
[requested_status, requested_string, ts, te] = Matlab_to_Optotrak('RequestNext3D');
disp(te - ts);

tstart = tic;
while toc(tstart)<collection_duration_loop
    loop_start = tic;
    % check for new sample
    [data_status, data, ts, te] = Matlab_to_Optotrak('DataReceiveLatest3D');
    time_save_here(1, t) = te - ts; % time for receive
    % request next sample
    if data_status ~= -1
        [requested_status, requested_string, ts, te] = Matlab_to_Optotrak('RequestNext3D');
        time_save_here(2, t) = te - ts; % time for request
    end

    % if data was returned
    if strcmp(data, 'DataNotReady') ~= 1 && data_status ~= -1
        save_here(i,:) = data;
        i = i+1;
        time_save_here(4, t) = data(1); % number of received frame
    end
    time_save_here(3, t) = toc(loop_start); % time for loop execution
    t = t+1;
end
% 
time_save_here(3, :) = time_save_here(3, :)*1000;
% postprocess possible requests that were not processed
pause(0.1);
% iterations = i;
% while Matlab_to_Optotrak('DataIsReady')
    [data_status, data] = Matlab_to_Optotrak('DataReceiveLatest3D');
    save_here(i,:) = data;
%     i = i+1;
% end
% disp(i - iterations);
disp('data ready after all?');
dataready = Matlab_to_Optotrak('DataIsReady')


Matlab_to_Optotrak('OptotrakStopCollection');

%%%% shutdown routines
[a b] = Matlab_to_Optotrak('OptotrakDeActivateMarkers'); %#ok<NASGU>
if (a ~= 0)
    display('Warning: OptotrakDeActivateMarkers died!');
    b
end
[a b] = Matlab_to_Optotrak('TransputerShutdownSystem');
if (a ~= 0)
    display('Warning: TransputerShutdownSystem died!');
    b
end
 
% Release the Matlab_to_Optotrak.mexw32 file, which allows it
% to be compiled in Visual C++ if needed.
clear mex;

%%% plot stuff
xlimits = [0 total_frame_num];
% let's plot the duration of each request
figure(123);
subplot(3,1,1);
plot(time_save_here(1,:), '.')
title('receive duration');
xlim(xlimits);
subplot(3,1,2);
plot(time_save_here(2,:), '.')
title('request duration');
xlim(xlimits);
subplot(3,1,3);
plot(time_save_here(3,:), '.')
title('loop duration');
xlim(xlimits);

% % let's plot the timestamps of each DataReceive
% time_between_samples = [];
% for i = 1:(length(save_here(:,13))-1)
%     time_between_samples(i) = save_here(i+1,13)-save_here(i,13);
% end    
% figure(124);
% plot(time_between_samples, '.');
% title('time between samples [ms]');
% xlim(xlimits);
% ylim([3000*(-1/collection_frequency) 3000*(1/collection_frequency)]);
