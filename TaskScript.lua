--------------------------------------------------------
-- А. Николенко 
-- 15.05.2019
-- 
-- Прошу не судить меня строго, 
-- данный файл есть мой первый срипт 
-- когда бы то ни было написанный на LUA.
--
-- Неделей ранее указанной даты о языке LUA
-- я знал только то что он существует.
--
-- Итак притупим ...
--------------------------------------------------------

--------------------------------------------------------
-- Глобальные переменные
--------------------------------------------------------

--------------------------------------------------------
-- Какие "логи" проверяются
--------------------------------------------------------
-- Каталог содержание которого необходимо проверить
mainDir = nil
-- Расширение файла стандартного вывода результатов теста 
fileext = ".stdout"
-- Первый ключевой каталог
keydir1 = "ft_reference"
-- Второй ключевой каталог
keydir2 = "ft_run"  

--------------------------------------------------------
-- Статистика проверки результатов тестирования
--------------------------------------------------------
-- массив всех найденных файлов стандартного вывода
-- с учётом полного пути
stdoutnames = {}
-- счётчик просмотренных подкаталогов 
countdirs = 0
-- счётчик ошибок error в результатах тестирования 
countError = 0
-- счётчик незавершёных тестов 
countUnfinishsdTest = 0
-- счётчик ошибок памяти 
countMemoryBadTest = 0
-- счётчик ошибок Total 
countTotalBadTest = 0

--------------------------------------------------------
-- Итоговый отчёт проверки результатов тестирования
--------------------------------------------------------
-- Файл отчёта 
fileReferenceResult = nil
-- Ошибка открытия файла итогового отчёта 
errFRR = nil
-- Буфер для сохранения ошибок найденных при проверки теста
arrayMessage = {}

--------------------------------------------------------
-- Начало ...
--------------------------------------------------------
print("")   
print("   Solving the problem of analyzing test results\n")

lfs = require "lfs"
if lfs ~= nil then
    print("   File system library \"lfs\" is load ")
else
    print("   Loading file system library \"lfs\" error")
    return  
end

--------------------------------------------------------
-- Проверяемый каталог теста как первый аргумент скрипта
--------------------------------------------------------
if #arg > 0 then
    mainDir = arg[1]
    -- Проверка существования каталога
    attr=lfs.attributes(mainDir)
    if attr == nil or attr.mode ~= "directory" then
        print("   Directory " .. mainDir .. " is absent\n")
        return
    end
else 
    mainDir = "."
end

--------------------------------------------------------
-- Округление числа до заданного числа знаков 
-- от 0 до 9 после запятой
--------------------------------------------------------
local roundV1 = {1, 10, 100, 1000, 10000, 100000,
      1000000, 10000000, 100000000, 1000000000}
function RoundFloat(num, k)
    if k<0 then k=0 end  
    if k>9 then k=9 end
    num = math.floor(num*roundV1[k+1]+0.5)/roundV1[k+1]
    return num
end

--------------------------------------------------------
-- Удаления пути каталога с логами из пути файла
--------------------------------------------------------
function ExcludeMainDirFromName(S)
    local n = #mainDir
    return string.sub(S, n+2)
end 

function ExcludeStrFor(S, forS)
    local j1, j2 = string.find(S, forS)
    if j2 then return string.sub(S, j2+1) end
    return S
end 

--------------------------------------------------------
-- Выделение ближайшего числа из строки
--------------------------------------------------------
function GetFirstNumber(S, j)
    local D
    local sD
    if j then
        -- Выделение подстроки с числом
        sD = string.sub(S, j)
    else 
        sD = S
    end    
    local j1, j2 = string.find(sD, " ")
    sD = string.sub(sD, 1, j1-1)
    D = tonumber(sD)
    return D
end

--------------------------------------------------------
-- Контролироль значения числа следующего Number
-- за ключевой фразой keyString
-- var  0 - последнее значение
--      1 - проверка на максимальное значение
--      2 - проверка на минимальное значение
--------------------------------------------------------
function checkKeyStringNumber(lowLine, keyString, num, var)
    -- Контролируемое значение
    local n = num
    -- Определение наличия в строке ключевой фразы
    local j1, j2 = string.find(lowLine, keyString)
    -- Если ключевой строки не найдено то искомое значени
    -- number не изменяется и возвращается обратно 
    if not j1 then return num end

    -- Емли ключевая фраза найдена, то 
    -- выделеняем подстроку которая начинается с числа            
    local stringMem = string.sub(lowLine, j2+1)           
    -- Преобразование подстроки в число
    n = GetFirstNumber(stringMem, 1)
    if not n then
        -- Ошибка преобразования данных строки в число
        -- Такое может быть если ф файле после ключевой 
        -- фразы отсутствует число, то есть в случае
        -- неверного формата файла
        
        return nil
    end
        
    if var == 1 then
        -- Контроль максимального значенния
        if not num or num < n then return n end
    elseif var == 2 then
        -- Контроль минимального значенния
        if not num or num > n then return n end 
    end
    -- Контроль последнего значения в файле соответствующего
    -- заданной ключевой фразе keyString
    return (n and n or num)
end

--------------------------------------------------------
-- Контролироль памяти
--------------------------------------------------------
function checkMemory(lowLine, memoryPeakMax)
    return checkKeyStringNumber(lowLine, 
           -- ключевая строка заданы в нижнем регистре 
           -- так как все строки анализируемого файла
           -- преобразуются к нижнему геристру для
           -- исключения несогласованности регистров
           -- ключевых фраз в файле и в шаблоне
           "memory working set peak = ", 
           memoryPeakMax, 1)
end

--------------------------------------------------------
-- Контролироль значения "Total"
--------------------------------------------------------
function checkTotal(lowLine, totalMax)
    return checkKeyStringNumber(lowLine, 
           -- ключевая строка заданы в нижнем регистре 
           -- так как все строки анализируемого файла
           -- преобразуются к нижнему геристру для
           -- исключения несогласованности регистров
           -- ключевых фраз в файле и в шаблоне      
           "mesh::bricks: total=", 
           totalMax, 0)
end
   
--------------------------------------------------------
-- Проверка содержимого файлов-результатов Run
-- на наличие ошибок тестирования
--------------------------------------------------------
function CheckingRunContent(fileName)
    -- Файл открывается для чтения
    local file, err = io.open(fileName, "r");
    
    -- Проверка корректности открытия файла 
    if not file or err then 
        -- Сообщение о неудачной попытке проверки 
        -- содержимого файла
        print( "")      
        print( "    Checking file " .. fileName .. " error ")
        -- Завершение проверки
        return -1, nil, nil
    end
    
    -- кол ошибки именно данный код возвращается процедурой
    err = 0
      
    -- Позиционирование указателя чтения на начало файла
    file:seek("set", 0)
    
    -- Построчное считываение файла и построчная же 
    -- проверка срдержимого файла
    local indexLine = 1
    local countFinish
    local memoryPeakMax
    local numberTotal
    local S
    for line in file:lines() do
        -- Документирование в консоль для отладки
        -- print(line)
        
        -- Переходим к строке в нижнем регистре
        -- для того чтоб избежать несовпадения регистра при 
        -- поиске в строке ключевого слова
        local lowLine = string.lower(line)
        
        -- Поиск в строке ключевого слова - сообщения
        -- об ошибке
        local j1, j2 = string.find(lowLine, "error")
        -- Вывод сообщения о найденной ошибке в тесте
        if j1 then
            err = 1  
            -- Емли ключевое слово "error" найдено 
            S = fileName .. "(" .. indexLine .. "): " ..  line
            print("   " .. S)
            -- Сохраняем сообщение об ошибке в буфере
            -- для последующего документирования в итоговом отчёте
            arrayMessage[#arrayMessage+1] = ExcludeStrFor(S, "ft_run\\")
            -- Увеличиваем счётчик найденных ошибок 
            countError = countError + 1
        end      
        
        -- Поиск в строке ключевой фразы - 
        -- завершение теста - если данной фразы в тесте 
        -- нет то тест считается не завершённым
        j1, j2 = string.find(lowLine, "solver finished at")
        if j1 then countFinish = 1 end
        
        -- Контролирование памяти
        memoryPeakMax = checkMemory(lowLine, memoryPeakMax)      
        
        -- Контролирование Total
        numberTotal = checkTotal(lowLine, numberTotal) 
        
        -- Увеличиваем счётчик строк
        indexLine = indexLine + 1
    end
    
    -- Файл закрывается
    file:close()    
    
    -- Вывод сообщения о незавершённом тесте
    if not countFinish then
        err = err + 2  
        S = fileName .. ": missing \'Solver finished at\'" 
        print("   " .. S)
        -- Сохраняем сообщение об ошибке в буфере
        -- для последующего документирования в итоговом отчёте
        arrayMessage[#arrayMessage+1] = ExcludeStrFor(S, "ft_run\\")
        -- Увеличиваем счётчик незавершённых тестов
        countUnfinishsdTest = countUnfinishsdTest + 1
    end
    
    -- Успешное завершение проверки - ошибок нет
    return err, memoryPeakMax, numberTotal
end

--------------------------------------------------------
-- Проверка содержимого файлов-результатов Ref
-- на наличие ошибок тестирования
--------------------------------------------------------
function CheckingRefContent(fileName)
    -- Файл открывается для чтения
    local file, err = io.open(fileName, "r");
    
    -- Проверка корректности открытия файла 
    if not file or err then 
        -- Сообщение о неудачной попытке проверки 
        -- содержимого файла
        print( "")      
        print( "    Checking file " .. fileName .. " error ")
        -- Завершение проверки
        return 1, nil, nil
    end
      
    -- Позиционирование указателя чтения на начало файла
    file:seek("set", 0)
    
    -- Построчное считываение файла и построчная же 
    -- проверка срдержимого файла
    local indexLine = 1
    local memoryPeakMax
    local numberTotal
    local S
    for line in file:lines() do       
        -- Переходим к строке в нижнем регистре
        -- для того чтоб избежать несовпадения регистра при 
        -- поиске в строке ключевого слова
        local lowLine = string.lower(line)
                      
        -- Контролирование памяти
        memoryPeakMax = checkMemory(lowLine, memoryPeakMax) 
        
        -- Контролирование Total
        numberTotal = checkTotal(lowLine, numberTotal)         
        
        -- Увеличиваем счётчик строк
        indexLine = indexLine + 1
    end
    
    -- Файл закрывается
    file:close()    
       
    -- Успешное завершение проверки - ошибок нет
    return 0, memoryPeakMax, numberTotal
end

--------------------------------------------------------
-- Проверка одной пары файлов Ref и Run теста
--------------------------------------------------------
function checkTestItem(dir, faleNaneRef, fileNameRun)
    local err3 = 0
    local rateMem, rateTotal
    local shortFileName = ExcludeStrFor(faleNaneRef, "ft_reference\\")
    -- Проверка Ref-файла 
    local err1, maxMem1, Total1 = CheckingRefContent(faleNaneRef)      
    -- Проверка Run-файла 
    local err2, maxMem2, Total2 = CheckingRunContent(fileNameRun)
    -- Максимум, минимум и отклонение maxMem    
    if maxMem1 and maxMem2 then
        local maxM =  math.max(maxMem1, maxMem2)
        local minM =  math.min(maxMem1, maxMem2)
        rateMem = (maxM - minM) / minM
    end
    -- Максимум, минимум и отклонение Total
    if Total1 and Total1 then
        local maxT = math.max(Total1, Total2)
        local minT = math.min(Total1, Total2)
        rateTotal = (maxT - minT)/ minT
    end  
    -- Вывод сообщения об ошибки памяти
    if not rateMem or rateMem>=4 then
        err3 = err3 + 1
        -- Вывод ошибки обьёма памяти
        S = shortFileName..": different \'Memory Working Set Peak\'"  
        S = S.."(ft_run="
        if maxMem2 then S = S..RoundFloat(maxMem2, 2) 
                   else S = S.."..." end        
        S = S..", ft_reference="
        if maxMem1 then S = S..RoundFloat(maxMem1, 2)  
                   else S = S.."..." end                     
        S = S..", rel.diff="
        if rateMem then S = S..RoundFloat(rateMem, 2) 
                   else S = S.."..." end
        S = S..", criterion=4)"
        print("   "..S)
        
        -- Сохраняем сообщение об ошибке в буфере
        -- для последующего документирования в итоговом отчёте
        arrayMessage[#arrayMessage+1] = S
        
        -- увеличение счётчика ошибок памяти
        countMemoryBadTest = countMemoryBadTest + 1
    end
    -- Вывод сообщения об ошибки значения Total
    if not rateTotal or rateTotal>=0.1 then
        err3 = err3 + 2 
        -- Вывод ошибки 
        S = shortFileName..": different \'Total\' of bricks "        
        S = S.."(ft_run="
        if Total2 then S = S..Total2 
                  else S = S.."..." end
        S = S..", ft_reference="
        if Total1 then S = S..Total1 
                  else S = S.."..." end        
        S = S..", rel.diff="
        if rateTotal then S = S..RoundFloat(rateTotal, 2)
                     else S = S.."..." end
        S = S..", criterion=0.1)"
        print("   "..S)   
        
        -- Сохраняем сообщение об ошибке в буфере
        -- для последующего документирования в итоговом отчёте
        arrayMessage[#arrayMessage+1] = S
        
        -- увеличение счётчика ошибок значения Total
        countTotalBadTest = countTotalBadTest + 1
    end
    return err1, err2, err3
end 

--------------------------------------------------------
-- Чего не хватает в массиве файлов L1
-- при сравнении с массивом L2
--------------------------------------------------------
function compareSimple(file, L1, L2, var, dir)
    -- Колличество файлов в каталоге ft_reference
    local n1 = L1 and #L1 or 0
    -- Колличество файлов в каталоге ft_run
    local n2 = L2 and #L2 or 0
    -- Колличество найденных не совпадений
    local countMissing = 0    
  
    -- Создадим "тень" для массивов L1
    local ShadowL1 = {}
    for i=1, n1 do ShadowL1[L1[i]] = true end
  
    -- Используя тень очень легко определим чего 
    -- не хватает в каталоге ft_reference 
    -- и чего не хватает в каталоге ft_run
    local S = ""
    for i=1, n2 do 
        if not ShadowL1[L2[i]] then
            -- файла L2[i] в из массива L2
            -- в массиве L1 нет
            -- Выводим об этом сообщение в отчёт
            if countMissing == 0 then
                if dir then
                    print("\n" .. "   " .. "Invalid structure of directory:")
                    print("   " .. dir) 
                end
                if var>0 then 
                    S = "In ft_run there are extra files not present in ft_reference: "
                else
                    S = "In ft_run there are missing files present in ft_reference: "
                end
                file.write(file, S, "\n")
                print("   " .. S)
            end
            if countMissing>0 then 
                S = S..", "
                file.write(file, ", ")
            end 
            S = S.."\""..L2[i].."\""
            file.write(file, L2[i])
            print("   ", L2[i])                
            countMissing = countMissing + 1
    end end 
    if countMissing > 0 then 
        file.write(file, "\n") 
        -- Сохраняем сообщение об ошибке в буфере
        -- для последующего документирования в итоговом отчёте
        if #S>0 then arrayMessage[#arrayMessage+1] = S end
    end   
    
    -- Возвращаем колличество найденных не совпадений
    return countMissing
end

--------------------------------------------------------
-- Сравнение содержимого каталогов ft_reference и ft_run
--------------------------------------------------------
function compareRefRun(dir, Ref, Run)
    -- Файл отчёта находится в каталоге вместе с подкаталогами
    -- ft_reference и ft_run в текущем просматриваемом
    -- каталоге dir. 
    
    -- Полное имя файла отчёта
    local fileReport = dir .. "\\" .. "report.txt"
    -- Удаляем старый отчёт
    os.remove(fileReport)
    -- Откроем данный файл для записи
    local file, err = io.open( fileReport, "w")  
  
    -- Сначала Run сравниваем с Ref
    local countM1 = compareSimple(file, Run, Ref, 0, 
                    dir )
    -- а потм наоборот - Ref сравниваем с Run 
    local countM2 = compareSimple(file, Ref, Run, 1, 
                    countM1 == 0 and dir or nil)    
    if countM1>0 or countM2>0 then print("") end
    
    -- Закрываем файл отчёта
    file:flush()
    file:close()    
    return countM1, countM2
end

--------------------------------------------------------
--------------------------------------------------------
-- Перебор содержимого каталога dir
-- Основная процедура скрипта
--------------------------------------------------------
--------------------------------------------------------
function checkingDirtory(dir, level)
    -- Проверка того задан абсолютный илиотносительный 
    -- путь к дирректории
    do
        local i, j = string.find( dir, ".")
        if not i or i ~= 1 then
            i, j = string.find( dir, ":\\")
            if i == nil then
                -- задан относитьельный путь к каталогу (от текущего)
                -- иправляем путь к каталогу добавив к нему путь к текущему каталогу
                local cd = lfs.currentdir()
                dir = cd .. "\\" .. dir
    end end end
  
    -- Проверка существования указанного дирректория
    local attr = lfs.attributes(dir)
    if attr == nil then
        print("   Directory " .. dir .. " is absent\n")  
        return nil
    end
   
    -- Признаки наличия первого и второго ключевых каталогов
    local countRef = 0
    local countRun = 0 
    local indexRef = 0  
    local indexRun = 0  
    -- Массив просмотренных каталогов
    local dirnames = {}
    -- Массив найденных файлов стандартного вывода результатов теста
    -- укороченные имена файлов
    local shortnames = {}  
  
    -- вычисление индекса с которого начинается имя файла с учётом
    -- дополнительных подкаталогов в одном из ключевых каталогов
    -- ft_reference или ft_run
    local jf
    do
        local i1, j1 = string.find( dir, keydir1)
        local i2, j2 = string.find( dir, keydir2)    
        jf = (j1 or j2)
        if jf then jf = jf + 1 end
    end
    -- если jf == nil то это означает, что ключевого каталога в пути 
    -- dir не содержится и следовательно формировать список файлов
    -- стандартного вывода не нужно
  
    level = level + 1  
  
    for entry in lfs.dir(dir) do
        if entry ~= "." and entry ~= ".." then 
        
            --if level == 3 then
            -- только на третьем уровне вложенности проверяем наличие
            -- подкаталогов ft_reference и ft_run
            if entry == keydir1 then 
                countRef = countRef + 1 
                indexRef = #dirnames+1
            end
            
            if entry == keydir2 then 
                countRun = countRun + 1 
                indexRun = #dirnames+1                  
            --end 
            end
          
            -- Формируется имя найденной сущьности с учётом полного пути
            local longentry = dir .. "\\" .. entry
          
            -- Атрибуты найденной сущьности
            attr=lfs.attributes(longentry)
          
            if attr.mode == "directory" then
                -- Найден подкаталог
                countdirs = countdirs + 1
                dirnames[#dirnames+1] = longentry
            else
                -- Найден файл
                if string.find( entry, fileext) then
                    -- Расширение файла соответствует файлу стандартного вывода
                  
                    -- Сохраняем укороченное имя файла начиная с улючевого
                    -- каталога
                    if jf then
                        local shortname = string.sub(longentry, jf+1)
                        shortnames[#shortnames+1] = shortname
                    end
                                    
                    -- Найденный файл сохраняется в массиве вмести со всем путём
                    -- к данному файлу
                    stdoutnames[#stdoutnames+1] = longentry
                    print(level, "  ", longentry)
    end end end end
  
    -- Признак необходимости дальнейшего продолжения проверки
    -- теста
    local needContinue = true
    -- Колличества несовпадений в ft_reference 
    -- и ft_run соответственно
    local countM1 = 0 
    local countM2 = 0    
    -- Общее колличество ошибок в тесте
    local countErr = 0 
  
    -- Признак того что просматриваемый каталог dir
    -- является тестом
    local isItTest = false
  
    -- Просмотр каталога закончен. Для третьего уровня вложенности 
    -- проверка наличия 
    -- каталогов ft_reference и ft_run
    if countRef > 0 or countRun > 0 then    
        local K = ""
        if countRef == 0 then K = keydir1 end
        if countRun == 0 then K = keydir2 end 
        
        if #K > 0 then           
            -- Сохраняем сообщение об ошибке в буфере
            -- для последующего документирования в итоговом отчёте
            arrayMessage[#arrayMessage+1] = "directory missing: "..K                          
          
            -- Выводим сообщение на консоль
            S = "directory missing: " .. dir .. "\\" .. K                      
            print( "\n".."    "..S)
            print( "    Directory " .. dir .. " is not checked\n")
            needContinue = false  
                       
            -- Увеличиваем счётчик ошибок в тесте
            countErr = countErr + 1
        end
        
        -- если обнаружены подкаталоги Ref и (или) Run то этот каталог - тест
        isItTest = true
    end 
  
    local newShortNamesKey1 = {}
    local newShortNamesKey2 = {}
  
    if needContinue == true then   
        for k, entry in pairs(dirnames) do
            -- Рекурсивный просмотр нового найденного каталога
            local newshortnames = checkingDirtory(entry, level)
            -- Список файлов стандартного вывода для ключевого каталога
            -- ft_reference
            if countRef > 0 and indexRef == k then 
                newShortNamesKey1 = newshortnames 
                newshortnames = nil
            end
            -- Список файлов стандартного вывода для ключевого каталога
            -- ft_run
            if countRun > 0 and indexRun == k then 
                newShortNamesKey2 = newshortnames 
                newshortnames = nil
            end          
            -- Если при просмотре подкаталога получен массив 
            -- укороченных имён файлов стандартного вывода, то 
            -- добавляем эти имена в таблицу имён shortnames
            if newshortnames then
                for i = 1, #newshortnames do 
                    shortnames[#shortnames + 1] = newshortnames[i]
        end end end
      
        ------------------------------------------------
        -- Проверка соответствия файлов в ключевых каталогах 
        -- ft_reference и ft_run
        ------------------------------------------------        
        -- колличества несовпадений в ft_reference 
        -- и ft_run соответственно
        if isItTest == true then
            if newShortNamesKey1 or newShortNamesKey2 then
                countM1, countM2 = 
                compareRefRun(dir, newShortNamesKey1, newShortNamesKey2)
        end end 
        
        -- Если несовпадения отсутствуют 
        -- то тест проверяется дальше
        
        if countM1==0 and countM2==0 then
            local refFileName, runFileName, refShortName 
            -- Проверка содержимого всех парных файлов для
            -- теста из каталога dir
            for k, runShortName in pairs(newShortNamesKey2) do            
                refShortName = newShortNamesKey1[k]
                refFileName  = dir.."\\"..keydir1.."\\"..refShortName
                runFileName  = dir.."\\"..keydir2.."\\"..runShortName
                -- Проверка содержимого одной пары файлов                
                local err1, err2, err3 = checkTestItem(dir, refFileName, runFileName)
                -- err1 - ошибки содержимого Ref-фалов    
                -- err2 - ошибки содержимого Run-фалов    
                -- err3 - ошибеи соответствия значений "Memory" и "Total"
                if err1==0 and err2==0 and err3 ==0 then
                    -- Тест успешный, без ошибок
                else
                    -- В тесте имеются ошибки
                    if err1>0 then countErr = countErr + 1 end
                    if err2>0 then countErr = countErr + 1 end
                    if err3>0 then countErr = countErr + 1 end
                end 
    end end end
        
    -- Документирование в файле итогового отчёта вердикта о корректности 
    -- теста dir. 
    -- dir содержит отчёт только в том случае если isItTest == true
    if fileReferenceResult and isItTest then
        local testName = ExcludeMainDirFromName(dir)
        if countErr>0 or countM1>0 or countM2>0 then                
            fileReferenceResult.write(fileReferenceResult, "FALL: ", testName, "\n")
            -- Документируем все сообщения о найденных ошибках в
            -- файл итогового отчёта
            for i, s in pairs(arrayMessage) do
                fileReferenceResult.write(fileReferenceResult, s, "\n")
            end    
            -- Удаляем все выданные в отчёт сообщения из оперативной памяти
            arrayMessage = nil
            -- Создаём заново пустой массив сообщений
            arrayMessage = {}
        else
            fileReferenceResult.write(fileReferenceResult, "OK: ", testName, "\n")      
    end end
    
    -- Просмотра каталога dir завершён 
  
    -- возвращается список найденных файлов стандартного вывода
    -- результатов теста
    if #shortnames == 0 then return nil end
    return shortnames
end
--------------------------------------------------------

-- Отображение в консоли проверяемого каталога
print("   Directory check: ", mainDir)

--------------------------------------------------------
-- Создание файла итогового отчёта
--------------------------------------------------------
-- Путь к файлу итогового отчёта о результатах проверки
-- Итоговый отчёт будет находится в каталоге логов
local nameReferenceResult = mainDir.."\\reference_result.txt"
-- Удаляем старый файл итогового отчёта 
os.remove(nameReferenceResult)
-- Открытие файла итогового отчёта о результатах проверки
fileReferenceResult, errFRR = io.open( nameReferenceResult, "w") 
-- Проверка корректности создания файла отчёта
if errFRR or not fileReferenceResult then
    print("   Reference result file creation error")
    return
end

--------------------------------------------------------
-- Вызов процедуры просмотра каталога и анализ его 
-- содержимого, поиск каталогов с результатами тестов,
-- поиск файлов-результатов теста проверка корректности 
-- структуры каталогов и наличия файлов-результатов,
-- проверка наличия в логах сообщений об ошибках... 
--------------------------------------------------------
checkingDirtory(mainDir, 0)

--------------------------------------------------------
-- Закрываем файл отчёта
--------------------------------------------------------
fileReferenceResult:flush()
fileReferenceResult:close()   

--------------------------------------------------------
-- Отчёт о результатах проверки теста в консоли
--------------------------------------------------------
print("")
print("   Total viewed directories:   ", countdirs)
print("   Total files checked:        ", #stdoutnames)
print("   Errors namber:              ", countError)
print("   Unfinished test namber:     ", countUnfinishsdTest)
print("   Bad memory test namber:     ", countMemoryBadTest)
print("   Bad memory \'Total\' namber:", countTotalBadTest)
print("")