if not ForgeSmall.isEnabled('editor') then return end

RegisterCommand('record', function()
    StartRecording(1)
    ForgeSmall.notify(locale('success.started_recording'), 'success')
end, false)

RegisterCommand('clip', function()
    StartRecording(0)
    ForgeSmall.notify(locale('success.stopped_recording'), 'success')
end, false)

RegisterCommand('saveclip', function()
    StopRecordingAndSaveClip()
    ForgeSmall.notify(locale('success.saved_recording'), 'success')
end, false)

RegisterCommand('delclip', function()
    StopRecordingAndDiscardClip()
    ForgeSmall.notify(locale('error.deleted_recording'), 'error')
end, false)

RegisterCommand('editor', function()
    NetworkSessionLeaveSinglePlayer()
    ActivateRockstarEditor()
    ForgeSmall.notify(locale('error.later_aligator'), 'error')
end, false)
