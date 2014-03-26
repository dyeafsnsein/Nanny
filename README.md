NannyBot
=====
Это кастомная русская версия программы NannyBot для игры Call of Duty 2. Оригинальным автором этой программы является smugllama. Написана полностью на Perl.
Оригинал можно скачать по этой ссылке http://smaert.com/nannybot.zip

По сравнению с оригиналом, почти всё было переведено на русский язык (шутки на английском остались),
также было исправлено много ошибок, переработаны некоторые функции, добавлены несколько новых команд, уменьшена агрессивность по отношению к игрокам.

Интсрукция по установке:

1. Необходимо скачать последние библиотеки ActivePerl http://www.activestate.com/activeperl/downloads. Перезагрузить компьютер.
2. Настроить необходимые параметры в nanny.cfg (переименуйте example.cfg). Подробно расписывать не буду, т.к там есть пояснения к каждому параметру.
4. Запустить. В Windows можно запускать через nannybot.bat, в других ос придется воспользоватся терминалом( perl "путь к nannybot.pl").

Опционально:

В Windows чтобы отображался русский язык необходимо запустить russian output support for windows.bat чтобы добавить его поддержку.

В Linux:
1. Открываем терминал
2. Идём в меню: Terminal >> Set Character Encoding >> Add or Remove...
3. Находим в Available encodings строку Cyrillic WINDOWS-1251 и добавляем её в Encodings shown in menu.