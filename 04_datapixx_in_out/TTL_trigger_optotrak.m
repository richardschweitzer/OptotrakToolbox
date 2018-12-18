% this is a general test to examine how the TTL scheduling works


try
    AssertOpenGL;   % We use PTB-3
    
    Datapixx('Open');
    Datapixx('StopAllSchedules');
    Datapixx('RegWrRd');    % Synchronize DATAPixx registers to local register cache
    
    % We'll make sure that all the TTL digital outputs are low before we start
    disp('Set TTL digital outputs to low');
    tic;
    Datapixx('SetDoutValues', 0);
    Datapixx('RegWrRd');
    toc;

    % Bring pin 7 on output high to start collection
    Datapixx('SetDoutValues', (2^6));
    Datapixx('RegWrRd');
    % Bring all the outputs low
    Datapixx('SetDoutValues', 0);
    Datapixx('RegWrRd');
    
    
    % pin 3 on serial port is 2^2
    % pin 7 on serial port is 2^6
    doutWave = [2^2 zeros(1,99)]; 
    bufferAddress = 8e6;
    Datapixx('WriteDoutBuffer', doutWave, bufferAddress);
    
    % Define the schedule which will play the wave.
    samplingRate = 12000; % makes 0.0000833 s
    seconds = 5;
    samplesPerTrigger = size(doutWave,2);
    triggersPerFrame = 1;
    samplesPerFrame = samplesPerTrigger * triggersPerFrame;
    framesPerTrial = 120*seconds;       % We'll send triggers for 120 video frames
    samplesPerTrial = samplesPerFrame * framesPerTrial;
%    Datapixx('SetDoutSchedule', 0, [samplesPerFrame, 2], samplesPerTrial, bufferAddress, samplesPerTrigger);
    disp('Schedule TTL trigger output sequence');
    tic;
    Datapixx('SetDoutSchedule', 0, [samplingRate, 1], samplesPerTrial, bufferAddress, samplesPerTrigger);
    toc;

    
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
    disp('Synchronize output sequence with next frame refresh');
    tic;
    Datapixx('StartDoutSchedule');
    PsychDataPixx('RequestPsyncedUpdate') % Mario Kleiner proposed this
    Datapixx('RegWrVideoSync');
    toc;
    pause(0.5);
    
    %% Insert visual stimulus animation code here.
    % The TTL triggers will begin during the first video frame defined here.
    vbl_times = zeros(1,framesPerTrial);
    for f = 1:framesPerTrial
        DrawFormattedText(window, num2str(f), 'center', 'center', white);
        vbl_times(f) = Screen('Flip', window);
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
        %regWrRd_tic = tic;
        Datapixx('RegWrRd');   % Update registers for GetDoutStatus
        %regWrRd_toc = toc(regWrRd_tic);
        status = Datapixx('GetDoutStatus');
        if ~status.scheduleRunning
            schedule_stopped = GetSecs;
            break;
        end
        if KbCheck
            Datapixx('StopDoutSchedule');
            Datapixx('RegWrRd');
            break;
        end
    end
    disp('duration of output sequence');
    disp(schedule_stopped-vbl_times(1));
    disp('first to last vbl');
    disp(vbl_times(end)-vbl_times(1));
    
    fprintf('\nStatus information for digital output scheduler:\n');
    Datapixx('RegWrRd');   % Update registers for GetAudioStatus
    disp(Datapixx('GetDoutStatus'));
    % Job done
    sca;
    Datapixx('Close');
    fprintf('\nDemo completed\n\n');


catch E
    % error exit
    sca;
    Datapixx('Close');
    fprintf('\nDemo error\n\n');
    rethrow(E);
end