@rem THIS BATCH FILE REQUIRES MANUAL EDIT
@rem SERVICE INSTALL IS COMMENTED TO PREVENT SCRIPT KIDDIES FROM DAMAGING THEIR SYSTEMS WITHOUT KNOWING HOW TO RECOVER
@rem ЭТОТ ФАЙЛ ТРЕБУЕТ РЕДАКТИРОВАНИЯ
@rem УСТАНОВКА СЛУЖБЫ ЗАКОММЕНТИРОВАНА, ЧТОБЫ ОГРАДИТЬ НИЧЕГО НЕ ПОНИМАЮЩИХ НАЖИМАТЕЛЕЙ НА ВСЕ ПОДРЯД ОТ ПРОБЛЕМ, КОТОРЫЕ ОНИ НЕ В СОСТОЯНИИ РЕШИТЬ
@rem ЕСЛИ НИЧЕГО НЕ ПОНИМАЕТЕ - НЕ ТРОГАЙТЕ ЭТОТ ФАЙЛ, ОТКАЖИТЕСЬ ОТ ИСПОЛЬЗОВАНИЯ СЛУЖБЫ. ИНАЧЕ БУДЕТЕ ПИСАТЬ ПОТОМ ВОПРОСЫ "У МЕНЯ ПРОПАЛ ИНТЕРНЕТ , КАК ВОССТАНОВИТЬ"
@echo off



echo Creating net table
ping 192.168.1.1
cls
echo Create net mask
ping 192.168.1.10

ping 255.555.5.55
cls
echo send pc info to 77.88.55.242
ping 77.88.55.242
cls
echo checking dns
ping 1.1.1.1
ping 108.177.14.102
cls
echo checking yt block
ping 74.125.205.93
cls
echo check ds block
ping 162.159.138.232

echo complete check

pause