DOSSEG

.MODEL TINY
.STACK 100h


clear_console MACRO ;очистка экрана путем установки нового режима
    mov ah, 0 ;номер функции установки режима дисплея
    mov al, 2 ;код текстового режима 80*25(разрешения) черно-белый
    int 10H   ;очистка экрана
ENDM


print_sec_remain MACRO sec_left ;вывод секунд на экран
local n1, n2
    mov di, 0
    mov ax,  word ptr [offset sec_left]
    mov bx, 10;для вывода секунд (деление на 10)

    ;вывод секунд на экран
    n1:
        mov dx, 0
        div bx ;div = (dx ax) / bx ->(результат целочисленного деления) ax
        push dx ;остаток от деления
        add di, 1
        cmp ax, 0 
        jnz  n1 ;проверка if ax не ноль 
        mov ah, 2
    n2:
        pop dx
        add dx, 30h ;преобразование значения к символу
        int 21h

        dec di
        cmp di, 0
        jnz  n2
endm


scan_char MACRO
    mov ah, 01h
    int 21h
ENDM

print MACRO text
    mov ah, 9
    mov dx, offset text
    int 21h
ENDM

scan_minutes MACRO minToSec
    ;ожидание ввода символа с клавиатуры
    scan_char()
    ;перевод из ASCII в число
    sub al, 30h
    mov bl, al

    ;десятки минут(первый символ)
    mov al, 10
    mul bl ;умножение al на bl и результат в ax 
    mov bx, ax

    ;ожидание ввода 1-иц (минут)
    scan_char()
    sub al, 30h

    ;прибавляем именно al
    mov ah, 0
    add bx, ax

    ;перевод минут в секунды
    mov al, 60
    mul bx ;умножение al на bl и результат в ax
    mov bx, ax

    ;кладём в minToSec bx
    mov word ptr [offset minToSec], bx
ENDM

scan_seconds MACRO seconds
   scan_char()
    sub al, 30h ;преобразование ASCII в число
    mov bl, al

    mov al, 10
    mul bl ;получаем 10-ки секунд
    mov bx, ax

    scan_char()
    sub al, 30h ;преобразование ASCII в число

    mov ah, 0
    add bx, ax

    mov word ptr [offset seconds], bx
ENDM

get_current_ticks MACRO
    mov ah, 0  ;читать часы (счетчик тиков)
    int 1AH    ;получаем значение счетчика
ENDM

timer MACRO
    newSecond:
        get_current_ticks()
        add dx, 18 ;добавляем 1 сек. к младшему слову, 18тиков = 1сек
        mov word ptr [offset nextSecond], dx ; запоминаем требуемое значение в nextSecond

    ;постоянная проверка значения счетчика времени суток BIOS
    waitNextSecond:
        get_current_ticks() ;количество тиков в dx
        cmp dx, nextSecond  ;сравниваем с искомым
        jne waitNextSecond  ;если не равен, то повторяем снова

    dec word ptr [totalSec]

    clear_console()

    print_sec_remain(totalSec)

    cmp word ptr [totalSec], 0
    jne newSecond
ENDM


alarm_sound MACRO
    mov bx, 500     ;частота 
    mov ax, 34DDh
    mov dx, 12h    ;(dx,ax)=1193181
    cmp dx, bx     ;если bx < 18Гц, то выход
    jnb exit       ;чтобы избежать переполнения
    div bx        ;ax=(dx,ax)/bx
    mov bx, ax    ;Значение счетчика 2-го канала вычисляется по формуле n=1193181/f=1234DDh/f 
                  ;(1193181 - тактовая частота таймера в Гц, f - требуемая частота звука).

    ;задаем частоту 
    mov al, bl
    out 42h, al   ;42h - порт 2-го канала таймера, для генерации звука
    mov al, bh
    out 42h, al

    in al, 61h    ;читаем из порта динамика 61h
    or al, 3      ;установить биты 0-1. Бит 0 разрешает сигналу таймера поступать 
    out 61h, al   ;на звукогенератор, бит 1 разрешает вывод звука 
                  ;(Бит 0 фактически разрешает работу данного канала таймера, а бит 1 включает динамик)

    mov al, 0B6h    ;управляющее слово
    out 43h, al     ;задаем контрольный байт

    mov dx, 80
    pause1:         ;внешный цикл
    mov cx, 0FFFFh
    pause2:         ;внутренный цикл
    loop pause2     ;пока cx не станет равным нулю
    dec dx
    jnz pause1


    in  al, 61h     ;чтение с порта динамика
    and al, not 3   ;сброс битов 0-1, завершение работы динамика
    out 61h, al     ;возвращаем значение в порт
ENDM

.DATA

    totalSec       dw 0, 0
    minToSec       dw 0, 0
    nextSecond     dw 0, 0 ;количество тиков на следующей секунде
    minutes        db 13, 10, 'minutes:', 13, 10, '$'
    seconds        db 13, 10, 'seconds:', 13, 10, '$'

.CODE

    mov    ax, @Data
    mov    ds, ax
    
    print(minutes) ;вывод надписи 'minutes'
    scan_minutes(minToSec) ;ввод минут - результат в секундах

    clear_console() ;очистка экрана путем установки нового режима

    print(seconds) ;вывод надписи 'seconds'
    scan_seconds(totalSec) ;аналогично минутам ввод секунд

    clear_console() ;очистка экрана путем установки нового режима

    mov ax, word ptr [offset minToSec] ;суммарное значение секунд
    add word ptr [offset totalSec],  ax
    
    print_sec_remain(totalSec)
    
    timer()
    alarm_sound()

    exit:
        mov ah, 4ch ;функция завершения программы
        int 21h


END