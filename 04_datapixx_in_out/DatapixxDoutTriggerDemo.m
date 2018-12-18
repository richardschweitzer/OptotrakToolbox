function DatapixxDoutTriggerDemo()
% DatapixxDoutTriggerDemo()
%
% Shows how to use a digital output schedule to generate a regular pulse train
% of TTL triggers.
% The pulse train begins at a vertical sync pulse,
% then generates 16 trigger pulses per video frame for the next 100 video frames.
%
% Also see: DatapixxDoutBasicDemo
%
% History:
%
% Oct 1, 2009  paa     Written
% Oct 29, 2014  dml     Revised

try
    AssertOpenGL;   % We use PTB-3
    
    Datapixx('Open');
    Datapixx('StopAllSchedules');
    Datapixx('RegWrRd');    % Synchronize DATAPixx registers to local register cache
    
    % We'll make sure that all the TTL digital outputs are low before we start
    tic;
    Datapixx('SetDoutValues', 0);
    Datapixx('RegWrRd');
    toc;
    
    % Define what we want a "trigger pulse" to look like,
    % then download it to the DATAPixx.
    % We'll arbitrarily say that it is 1 sample high, and 3 samples low.
    doutWave = [-4 0];
    bufferAddress = 8e6;
    Datapixx('WriteDoutBuffer', doutWave, bufferAddress);
    
    % Define the schedule which will play the wave.
    samplesPerTrigger = size(doutWave,2);
    triggersPerFrame = 1;
    samplesPerFrame = samplesPerTrigger * triggersPerFrame;
    framesPerTrial = 100;       % We'll send triggers for 100 video frames
    samplesPerTrial = samplesPerFrame * framesPerTrial;
%    Datapixx('SetDoutSchedule', 0, [samplesPerFrame, 2], samplesPerTrial, bufferAddress, samplesPerTrigger);
    tic;
    Datapixx('SetDoutSchedule', 0, [0.008333, 3], samplesPerTrial, bufferAddress, samplesPerTrigger);
    toc;
    PsychDataPixx('RequestPsyncedUpdate');
    
    %% Insert your visual stimulus setup code here, finishing up with a Screen('Flip', window);
    screens = Screen('Screens');
    screenNumber = max(screens);
    % Define black, white and grey
    black = BlackIndex(screenNumber);
    white = WhiteIndex(screenNumber);
    grey = white / 2;
    % Open an on screen window and color it grey
    [window, windowRect] = PsychImaging('OpenWindow', screenNumber, grey);
    f = 0;
    DrawFormattedText(window, num2str(f), 'center', 'center', white);
    Screen('Flip', window);
    
    % Tell the trigger schedule to start on the next vertical sync pulse
    tic;
    Datapixx('StartDoutSchedule');
    Datapixx('RegWrVideoSync');
    toc;
    %pause(0.5);
    
    %% Insert visual stimulus animation code here.
    % The TTL triggers will begin during the first video frame defined here.
    for f = 1:framesPerTrial
        DrawFormattedText(window, num2str(f), 'center', 'center', white);
        Screen('Flip', window);
        %pause(0.1);
        if KbCheck
            break
        end
    end
    
    % We'll wait here until the digital output schedule has completed,
    % or user aborts with a keypress.
    fprintf('\nTrigger output started, press any key to abort.\n');
    if (exist('OCTAVE_VERSION'))
        fflush(stdout);
    end
    while 1
        Datapixx('RegWrRd');   % Update registers for GetDoutStatus
        status = Datapixx('GetDoutStatus');
        if ~status.scheduleRunning
            break;
        end
        if KbCheck
            Datapixx('StopDoutSchedule');
            Datapixx('RegWrRd');
            break;
        end
    end
    
    fprintf('\nStatus information for digital output scheduler:\n');
    Datapixx('RegWrRd');   % Update registers for GetAudioStatus
    disp(Datapixx('GetDoutStatus'));
    % Job done
    Datapixx('Close');
    sca;
    fprintf('\nDemo completed\n\n');


catch E
    % error exit
    Datapixx('Close');
    sca;
    fprintf('\nDemo error\n\n');
    rethrow(E);
end