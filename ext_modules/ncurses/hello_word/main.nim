#[
    Basics for ncurses

    If the terminal size is too small, it may collapse.
    Also, resizing would cause crash
]#

import ncurses

proc main(): void =
    var
        # if you set mesg: string or mesg = "", it will cause nil access
        mesg = " "
        row: cint
        col: cint

        left_up_y, left_up_x, height, width: cint

    let pwin = initscr()

    getmaxyx(pwin, row, col)

    height = 10
    width = 30
    left_up_y = (row div 2)-(height div 2)
    left_up_x = (col div 2)-(width div 2)

    var local_win = newwin(height, width, left_up_y, left_up_x);

    #[
        0, 0 gives default characters 
        for the vertical and horizontal lines

    ]#
    box(local_win, 0, 0);
    # manual selecting the border character
    #wborder(local_win, (chtype)'|', (chtype)'|', (chtype)'-', (chtype)'-', (chtype)'+', (chtype)'+', (chtype)'+', (chtype)'+');
    
    # not possible, it will interpret as a border(local_win, ...) for each line
    #local_win.border.ls = (chtype)'|';
    #local_win.border.rs = '|';
    #local_win.border.ts = '-';
    #local_win.border.bs = '-';
    #local_win.border.tl = '+';
    #local_win.border.tr = '+';
    #local_win.border.bl = '+';
    #local_win.border.br = '+';

    mvwprintw(pwin, 0, 0, "This comes at top left!")
    mvwprintw(pwin, left_up_y-1, left_up_x, "local_win - border comes from box()")

    wattron(local_win, (cint)A_REVERSE)
    mvwprintw(local_win, 2, 2, "Hello, World!")
    wattroff(local_win, (cint)A_REVERSE)
    mvwprintw(local_win, 4, 3, "Type some keys,")
    mvwprintw(local_win, 5, 4, "then press Enter.")
    mvwprintw(local_win, 7, 3, "Typed words will appear in")
    # of course you can write in nim-style
    local_win.mvwprintw(8, 4, "the left bottom corner.")

    # you can use string param
    mvprintw((row div 2)+height-2, (cint)(((col - mesg.len) div 2)-20), "%s", "what you have been typed: ")

    #[
        in this case, 
        refreshing order must be keeped

        because if you refresh() after wrefresh(local_win),
        it will overwrite all the content of local_win with the pwin content
        
        this occurs from refresh() is pointing the pwin (content).
    ]#
    refresh()
    # draw update
    wrefresh(local_win)

    getstr(mesg)

    attron((cint)A_REVERSE)
    mvprintw(row - 2, 0, "You Entered: %s", mesg)
    attroff((cint)A_REVERSE)

    # actually, it is not `any key`, I mean, it does not read all the input from the keyboard.
    # not talking about searching the `any` key on keyboard: https://en.wikipedia.org/wiki/Any_key
    mvprintw(row - 1, 0, "see you, good bye. press any key to exit.")
    getch()
    endwin()

main()
