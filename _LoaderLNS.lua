warning = function() 
    return  
end
warn = function() 
    return  
end
error = function() 
    return  
end

local urlLoader = 'https://raw.githubusercontent.com/lnsscripts/LNS-CUSTOM-ARCHIVES/refs/heads/main/LNS-LOADER.lua'
doLoadCustom = function()
    if loadRemoteScript and type(loadRemoteScript) == 'function' then
        loadRemoteScript(urlLoader)
        return
    end

    HTTP.get(urlLoader, function(content, err)
        if (err) or (not content or content == "") then
            print(err or "Erro de conexao/conteudo vazio")
            return schedule(3000, doLoadCustom)
        end
        
        local carregar = loadstring(content)
        if carregar then
            carregar()
            
            if loadRemoteScript then
                loadRemoteScript(urlLoader)
            end
        else
            print("Erro de sintaxe no script baixado")
            return schedule(3000, doLoadCustom)
        end
    end)
end

doLoadCustom()
