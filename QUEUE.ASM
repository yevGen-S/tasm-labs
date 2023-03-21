DOSSEG
.MODEL tiny
.386
.STACK 100h

new_line_return_carriage macro
    mov al,10 ;перенос строки
    int 29h
    mov al,13 ;возврат каретки
    int 29h
endm

.DATA

 fifo  DB  10 dup ('-') ;очередь
 
 fifo_size DW  8 ;размер очереди
 fifo_end DW  0 ;указывает на конец очереди (изначально, когда очередь пуста, ее конец - 0)

 wr_num DW  0 ;количество записываемых элементов
 rd_num DW  0 ;количество читаемых элементов
 
 f_msg      DB 'FIFO: ',                                          10,13,'$'
 input_msg  DB 'Enter number of elements to input:',              10,13,'$'
 elem_msg   DB 'Enter elements of array:',                        10,13,'$'
 output_msg DB 'Enter number of elements for output:',            10,13,'$'
 empty_msg  DB 'FIFO is empty!',                                  10,13,'$'
 full_msg   DB 'FIFO is full!',                                   10,13,'$'
 excess_msg DB 'Your number > available. Max available:',         10,13,'$'
 retry_msg  DB 'Your number is bigger than available. Try again!',10,13,'$'
 

.CODE



;ПРОЦЕДУРА ДЛЯ ВЫВОДА НА ЭКРАН СОДЕРЖИМОГО ОЧЕРЕДИ

print_fifo proc
;вывод надписи "FIFO: "
    mov ah,9h
    mov dx,offset f_msg
    int 21h
;вывод содержимого очереди
    xor si,si ;зануляем si
    lea bx,fifo ;в bx пишем сдвиг до fifo
    mov cx,fifo_size
print:
    mov dl,[bx+si] ;кладем в регистр dl значение по адресу bx + инкрементор si
    mov ah,2h ; функция вывода символа на экран
    int 21h
    inc si
loop print

new_line_return_carriage()

ret
print_fifo endp



;ПРОЦЕДУРА ВКЛЮЧЕНИЯ НОВЫХ ЭЛЕМЕНТОВ В ОЧЕРЕДЬ

write_fifo proc
;проверка заполненности очереди
    mov ax,fifo_size
    cmp fifo_end,ax
    je full_label

;вывод сообщения о количестве заполняемых элементов
    mov ah,9h
    mov dx,offset input_msg
    int 21h

;ввод количества заполняемых элементов
    mov ah,0 ;ввод информации в консоль (ожидание ввода символа)
    int 16h ;запись симфола в al
    mov byte ptr wr_num,al ;запись числа в переменную
    sub word ptr wr_num,30h ;преобразование ASCII кода в число
    mov dl,al ;вывод введенного числа
    mov ah,2
    int 21h   

    new_line_return_carriage()

;проверка wr_num на превышение количества свободных мест очереди
    mov bx,fifo_end
    mov ax,fifo_size
    sub ax,bx
    mov bx,wr_num
    cmp bx,ax
    jbe access_label ;если хотим записать количество элементов меньше или равно\
                     ;свободному количеству ячеек в очереди

    ;выводим сообщение о превышении возможного кол-ва элементов для ввода
        mov ah,9h
        mov dx,offset excess_msg
        int 21h
    ;записываем в wr_num разность fifo_size и fifo_end
        mov bl,byte ptr fifo_end
        mov al,byte ptr fifo_size
        sub al,bl
        mov byte ptr wr_num,al
        add al,30h ;преобразование числа к символу ASCII
        int 29h

        new_line_return_carriage()

    access_label:
    ;вывод сообщения о заполнении очереди
        mov ah,9h
        mov dx,offset elem_msg
        int 21h
    ;заполнение очереди
        xor si,si
        add si,fifo_end
        lea bx,fifo
        mov cx,wr_num

    input:
        mov ah,0 ;ввод информации в консоль (ожидание ввода символа)
        int 16h ;запись симфола в al
        mov [bx+si],al ;в bx+si записываем введенный символ
        inc si
        mov dl,al ;кладем в dl <- al для вывода на сивола на экран
        mov ah,2
        int 21h
    loop input

    ;обновляем значение fifo_end
    mov bx,wr_num
    add fifo_end,bx
    jmp end_writing

    ;вывод сообщения о заполненности очереди
    full_label: 
        mov ah,9h
        mov dx,offset full_msg
        int 21h

    end_writing:
        new_line_return_carriage()

    ret
write_fifo endp



;ПРОЦЕДУРА ЧТЕНИЯ ИЗ ОЧЕРЕДИ 
;(удаление эдементов из очереди, их отображение и сдвиг очереди)

read_fifo proc
;проверка на пустоту очереди
    cmp fifo_end,0
    je empty_label

    try_again:
    ;вывод сообщения о количестве читаемых элементов
        mov ah,9h
        mov dx,offset output_msg
        int 21h

    ;ввод количества читаемых элементов
        mov ah,0 ;ввод информации в консоль (ожидание ввода символа)
        int 16h ;запись симфола в al
        mov byte ptr rd_num,al ;запись числа в переменную
        sub word ptr rd_num,30h ;преобразование ASCII кода в число

    ;проверка rd_num на превышение количества лежащих в очереди элементов
        mov bx,rd_num
        cmp bx,fifo_end
        ja retry_label ;если количество читаемых элементов больше 
                        ;количества элементов, лежащих в очереди

        mov dl,al ;вывод введенного числа
        mov ah,2
        int 21h

        new_line_return_carriage()

    ;чтение из очереди
        xor si,si
        lea bx,fifo
        mov cx,rd_num
    output:
        mov dl,[bx+si]
        mov ah,2
        int 21h
        inc si
    loop output

    xor di,di
    xor si,si
    add si,rd_num
    lea bx,fifo
    mov cx,fifo_end
    sub cx,rd_num

    ;проверка, что число читаемых значений равно числу лежащих в очереди значений
    cmp cx, 0
    je delete_fifo_elems

    ;сдвиг элементов
    moving:
        mov al,[bx+si]
        mov [bx+di],al
        inc di
        inc si
    loop moving

    ;зачистка
    delete_fifo_elems:
        mov fifo_end,di
        mov si,fifo_end
        mov cx,fifo_size
        sub cx,fifo_end

    erasing:
        mov byte ptr [bx+si],'-'
        inc si
    loop erasing

    jmp end_reading
    ;вывод сообщения о том, что очередь пуста
    empty_label:
        mov ah,9h
        mov dx,offset empty_msg
        int 21h
        jmp end_reading

    ;вывод сообщения о том, что введено большое число
    retry_label:
        mov ah,9h
        mov dx,offset retry_msg
        int 21h
        jmp try_again
        
    end_reading:
        new_line_return_carriage()
    ret
read_fifo endp



;начало основной программы
start:

    mov ax,@data
    mov ds,ax
    xor ax,ax

    call write_fifo 
    call print_fifo
    call read_fifo 
    call print_fifo
    call write_fifo 
    call print_fifo
    call read_fifo 
    call print_fifo

    mov ax,4c00h ;выход
    int 21h


END start


