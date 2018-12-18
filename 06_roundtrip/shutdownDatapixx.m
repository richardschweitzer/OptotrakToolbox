function shutdownDatapixx
    status = Datapixx('GetDoutStatus');
    if status.scheduleRunning
        Datapixx('StopDoutSchedule');
    end
    Datapixx('SetDoutValues', 0);
    Datapixx('RegWrRd');
    Datapixx('Close');
end