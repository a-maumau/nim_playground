#[
    move the window with arrow keys
]#

import ncurses

proc main(): void =
    let
        pwin = initscr()
        
        win_row: cint = 12
        win_col: cint = 12
        pad_row: cint = 10
        pad_col: cint = 10

    keypad(pwin, true);

    # for no input showing on screen
    noecho()
    # disable cursor
    curs_set(0)

    refresh()

    var
        row: cint
        col: cint

    getmaxyx(pwin, row, col)

    let
        scroll_y_max = row-win_row
        scroll_x_max = col-win_col

    var local_win = newwin(win_row, win_col, 0, 0)
    #var local_win = newpad(win_row, win_col);
    box(local_win, 0, 0)

    # subpad only work on if parent is pad 
    #var local_pad = subpad(local_win, pad_row, pad_col, 1, 1)

    # create subwindow
    # the last two args are not related position of parent window,
    # so you need to give a correct absolute position of terminal.
    # or you may create a parent window and sub window on the global (0,0)
    # ,and then, use mvwin(pwin, row, col) to move where you want to put
    var local_pad = subwin(local_win, pad_row, pad_col, 1, 1)
    
    # enable scroll, if printing overrun the size, it automatically scroll
    # in this following case, the part of the sentence "This is a ..." will be omitted
    scrollok(local_pad, true)

    mvwprintw(local_pad, 0, 0, "This is a content for a sub win/paaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaad")

    #prefresh(local_pad, 0, 0, 0, 0, 10, 10)
    mvprintw(15, 1, "press arrow key, it will change pminrow, pmincol")
    mvprintw(16, 1, "to quit, press q")

    refresh()
    wrefresh(local_win)
    wrefresh(local_pad)
    #prefresh(local_win, 0, 0, 0, 0, 10, 10)
    #prefresh(local_pad, 0, 0, 0, 0, 10, 10)

    var
        k: int
        mrow: cint = 0
        mcol: cint = 0

    let
        keyQiut = (int64)((chtype)'q')

    while true:
        # return int64 
        k = getch()

        if k == keyQiut:
            break

        elif k == KEY_UP:
            if mrow > 0:
                mrow -= 1

        elif k == KEY_DOWN:
            if mrow < scroll_y_max:
                mrow += 1

        elif k == KEY_RIGHT:
            if mcol < scroll_x_max:
                mcol += 1

        elif k == KEY_LEFT:
            if mcol > 0:
                mcol -= 1

        #[
            scrl will scrolling, but it seems it will not will the content
            which leads us to manually add somthing to a blank line
        ]#
        # pageup
        elif k == KEY_PPAGE:
            wscrl(local_pad, -1)

        # pagedown
        elif k == KEY_NPAGE:
            wscrl(local_pad, 1)

        # this moves cursor
        #wmove(local_win, mrow, mcol)

        mvwin(local_win, mrow, mcol)

        clear()
        refresh()
        wrefresh(local_win)
        wrefresh(local_pad)
        #prefresh(local_pad, 0, 0, 0, 0, 10, 10)

        mvprintw(15, 1, "press arrow key, it will change pminrow, pmincol")
        mvprintw(16, 1, "to quit, press q")

    endwin()

main()
