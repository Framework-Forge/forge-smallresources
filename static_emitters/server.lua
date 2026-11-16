if not ForgeSmall.isEnabled('staticEmitters') then return end

pr_lib.callback.register('forge-smallresources:server:isStaticEmitterAdmin', function(src)
    return IsPlayerAceAllowed(src, 'admin')
end)