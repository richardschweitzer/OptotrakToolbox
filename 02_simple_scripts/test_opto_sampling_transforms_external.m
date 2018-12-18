% test the new non-blocking routine with TRANSFORMS

addpath('\\KASTORI\Users\sysop\Documents\Visual Studio 2015\Projects\Matlab_to_Optotrak\Debug')    
%clear all;
 
collection_num_markers_1 = 3;     		% number of markers on port 1: marker strober
collection_num_markers_2 = 6;     		% number of markers on port 2: wireless strober
start_marker_3d = 1;                    % when requesting transforms, from which marker on do we want to see 3d data
end_marker_3d = 9;                      
assert(end_marker_3d<=collection_num_markers_1+collection_num_markers_2);
collection_frequency = 130;     		% Hz
collection_duration = 10;        		% s
collection_duration_loop = 8;
%cam_filename = 'Aligned20160704_1';     % .cam file for sensor. % name of sensor: C3-04864
%cam_filename = 'Aligned20160727';
cam_filename = 'Aligned20160728';
%cam_filename = 'standard';
rigid_filename_0 = 'schrank_4';
rigid_filename_1 = 'spinal_2';
rigid_filename_2 = 'spinal_3';

external_yes = 1;


total_frame_num = collection_frequency * collection_duration_loop;

% setup routines for Optotrak
[a b] = Matlab_to_Optotrak('TransputerLoadSystem', collection_num_markers_1, collection_num_markers_2, ...
            collection_frequency, collection_duration, cam_filename, external_yes);	
if (a ~= 0)
    error('TransputerLoadSystem died!');
    b
end

pause(1);



% load the shelf
[a b] = Matlab_to_Optotrak('RigidBodyAddFromFile', 0, 1, rigid_filename_0);
if (a ~= 0)
    error('RigidBodyAddFromFile did not work!');
    b
end



% load the first rigid object
[a b] = Matlab_to_Optotrak('RigidBodyAddFromFile', 1, 4, rigid_filename_1);
if (a ~= 0)
    error('RigidBodyAddFromFile did not work!');
    b
end

% [a b] = Matlab_to_Optotrak('RigidBodyDelete', 0);
% if (a ~= 0)
%     error('RigidBodyDelete did not work!');
%     b
% end

% load the second rigid object
[a b] = Matlab_to_Optotrak('RigidBodyAddFromFile', 2, 7, rigid_filename_2);
if (a ~= 0)
    error('RigidBodyAddFromFile did not work!');
    b
end



[a b] = Matlab_to_Optotrak('OptotrakActivateMarkers'); %#ok<NASGU>
if (a ~= 0)
    error('OptotrakActivateMarkers died!');
    b
end



% let's not write into a buffer, but just sample in matlab
save_here = [];
time_save_here = [];
i = 1;
t = 1;

pause(1);
disp('Sampling started');
%[requested_status, requested_string, ts, te] = Matlab_to_Optotrak('RequestNext3D');
[requested_status, requested_string, ts, te] = Matlab_to_Optotrak('RequestNextTransforms');

tstart = tic;
while toc(tstart)<collection_duration_loop
    loop_start = tic;
    % check for new sample
    %[data_status, data, ts, te] = Matlab_to_Optotrak('DataReceiveLatest3D');
    [data_status, data, ts, te] = Matlab_to_Optotrak('DataReceiveLatestTransforms', start_marker_3d, end_marker_3d);
    time_save_here(1, t) = te - ts; % time for receive
    % request next sample
    if data_status ~= -1
        disp(data);
        %[requested_status, requested_string, ts, te] = Matlab_to_Optotrak('RequestNext3D');
        [requested_status, requested_string, ts, te] = Matlab_to_Optotrak('RequestNextTransforms');
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
    [data_status, data] = Matlab_to_Optotrak('DataReceiveLatestTransforms', start_marker_3d, end_marker_3d);
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

%%% time
timestamps = save_here(:,63);
diff_timestamps = diff(timestamps);
mean(diff_timestamps)
figure(124);
plot(diff_timestamps, '.');

clear mex;
% let's plot the timestamps of each DataReceive
% time_between_samples = [];
% for i = 1:(length(save_here(:,13))-1)
%     time_between_samples(i) = save_here(i+1,13)-save_here(i,13);
% end    
% figure(124);
% plot(time_between_samples, '.');
% title('time between samples [ms]');
% xlim(xlimits);
% ylim([3000*(-1/collection_frequency) 3000*(1/collection_frequency)]);
