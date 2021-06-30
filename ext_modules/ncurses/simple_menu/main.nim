#[
    refreshing a screen, I think there are some methods which we can take:
        1. create a window for each content
        2. rewrite the content for each time on one window

    I don't know which is a practical way.

    if the multiple content always remain and only happens adding,
    then, using multiple window is much faster, I think.
    because if you use single window, it always needs a constructing a content.
    refreshing is not a cost (either way, it always happens when we rewrite the content).
]#

import strutils
import strformat

import ncurses

start_color()
init_pair(1, COLOR_CYAN, COLOR_BLACK)

proc createContent0(pwin: var PWindow) =
    mvwprintw(pwin, 0, 0, "this is the content #0")
    mvwprintw(pwin, 2, 0, "press up/down arrow keys to change content.")
    mvwprintw(pwin, 3, 0, "this time, menu number only moves in 0~3")
    mvwprintw(pwin, 4, 0, "press Q to quit")

proc createContent1(pwin: var PWindow) =
    mvwprintw(pwin, 0, 0, "this is the content #1\nbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")

proc createContent2(pwin: var PWindow) =
    mvwprintw(pwin, 0, 0, "this is the content #2\ncccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc")

proc createContent3(pwin: var PWindow) =
    mvwprintw(pwin, 0, 0, "this is the content #3\nddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd")

proc main(): void =
    let
        mainWin = initscr()

    # to parse arrow keys by KEY_UP, ...
    keypad(mainWin, true);

    # for no input showing on screen
    noecho()
    # disable cursor
    curs_set(0)

    refresh()

    var
        mainWinRow: cint
        mainWinCol: cint
        contentWinRow: cint
        contentWinCol: cint

        menuWinCol:cint = 10

    getmaxyx(mainWin, mainWinRow, mainWinCol)

    # menu window setup
    var menuWindow = newwin(mainWinRow, menuWinCol, 0, 0)
    menuWindow.box(0, 0)

    var menuWindowContent = menuWindow.subwin(mainWinRow-2, menuWinCol-2, 1, 1)
    menuWindowContent.mvwprintw(0, 0, "   #0   ")
    menuWindowContent.mvwprintw(1, 0, "   #1   ")
    menuWindowContent.mvwprintw(2, 0, "   #2   ")
    menuWindowContent.mvwprintw(3, 0, "   #3   ")

    # content windows setup
    var contentWindow = newwin(mainWinRow, mainWinCol-menuWinCol, 0, menuWinCol)
    contentWindow.box(0, 0)
    getmaxyx(contentWindow, contentWinRow, contentWinCol)

    # sub window will rendered at the refresh(pwin), so it will draw all content
    # which we do not expect
    # subwin()'s last two args are not relative positions, it is using the screen (terminal) positions.
    #var contentWindowContent0 = contentWindow.subwin(contentWinRow-2, contentWinCol-2, 1, menuWinCol+1)
    #var contentWindowContent1 = contentWindow.subwin(contentWinRow-2, contentWinCol-2, 1, menuWinCol+1)
    #var contentWindowContent2 = contentWindow.subwin(contentWinRow-2, contentWinCol-2, 1, menuWinCol+1)
    #var contentWindowContent3 = contentWindow.subwin(contentWinRow-2, contentWinCol-2, 1, menuWinCol+1)

    var contentWindowContent0 = newwin(contentWinRow-2, contentWinCol-2, 1, menuWinCol+1)
    var contentWindowContent1 = newwin(contentWinRow-2, contentWinCol-2, 1, menuWinCol+1)
    var contentWindowContent2 = newwin(contentWinRow-2, contentWinCol-2, 1, menuWinCol+1)
    var contentWindowContent3 = newwin(contentWinRow-2, contentWinCol-2, 1, menuWinCol+1)

    createContent0(contentWindowContent0)
    createContent1(contentWindowContent1)
    createContent2(contentWindowContent2)
    createContent3(contentWindowContent3)

    # it seems not working...
    wattron(contentWindowContent0, COLOR_PAIR(1).cint)
    mvwprintw(contentWindowContent0, 5, 0, "test colored text")
    wattroff(contentWindowContent0, COLOR_PAIR(1).cint)

    var
        contentWindows: seq[PWindow] = @[contentWindowContent0,
                                         contentWindowContent1,
                                         contentWindowContent2,
                                         contentWindowContent3]

    #wrefresh(menuWindowContent)
    #wrefresh(contentWindow)

    var
        k: cint
        menuID: cint = 0

    let
        keyQiut = (int64)((chtype)'q')
        key0 = (int64)((chtype)'0')
        key3 = (int64)((chtype)'3')

    wmove(menuWindowContent, menuID, 0)
    wattron(menuWindowContent, (cint)A_REVERSE)
    winsnstr(menuWindowContent, fmt"   #{menuID}   ", 8)
    wattroff(menuWindowContent, (cint)A_REVERSE)

    # every thing including moving the cursor will update
    # if you call related win/pad is updated by refresh()
    # display update, which only draws boarder
    wrefresh(menuWindow)
    #wrefresh(menuWindowContent)
    wrefresh(contentWindowContent0)

    while true:
        # return int64 
        k = getch()

        if k == keyQiut:
            break

        # redrawing the menu
        elif k == KEY_UP:
            if menuID > 0:
                wmove(menuWindowContent, menuID, 0)

                # this will erace all the content
                #werase(menuWindowContent)
                #wclear(menuWindowContent)
                # this will erace the content from cursor to end of window
                #wclrtobot(menuWindowContent)
                # this will erace the content from cursor to end of line
                wclrtoeol(menuWindowContent)

                winsnstr(menuWindowContent, fmt"   #{menuID}   ", 8)

                # refresh() only draws the update
                # so if we need to draw the same content
                # we need to set the window to need update state
                # you can use redrawwin() too
                touchwin(contentWindows[menuID])

                menuID -= 1

                wmove(menuWindowContent, menuID, 0)
                wattron(menuWindowContent, (cint)A_REVERSE)
                winsnstr(menuWindowContent, fmt"   #{menuID}   ", 8)
                wattroff(menuWindowContent, (cint)A_REVERSE)

                wrefresh(contentWindows[menuID])

        elif k == KEY_DOWN:
            if menuID < 3:
                wmove(menuWindowContent, menuID, 0)
                wclrtoeol(menuWindowContent)
                winsnstr(menuWindowContent, fmt"   #{menuID}   ", 8)

                touchwin(contentWindows[menuID])

                menuID += 1

                wmove(menuWindowContent, menuID, 0)
                wattron(menuWindowContent, (cint)A_REVERSE)
                winsnstr(menuWindowContent, fmt"   #{menuID}   ", 8)
                wattroff(menuWindowContent, (cint)A_REVERSE)

                wrefresh(contentWindows[menuID])

        elif k >= key0 and k <= key3:
            wmove(menuWindowContent, menuID, 0)
            wclrtoeol(menuWindowContent)
            winsnstr(menuWindowContent, fmt"   #{menuID}   ", 8)

            touchwin(contentWindows[menuID])

            # in ascii code, "0" is 48
            menuID = k-48

            wmove(menuWindowContent, menuID, 0)
            wattron(menuWindowContent, (cint)A_REVERSE)
            winsnstr(menuWindowContent, fmt"   #{menuID}   ", 8)
            wattroff(menuWindowContent, (cint)A_REVERSE)

            wrefresh(contentWindows[menuID])

        wrefresh(menuWindowContent)

    endwin()

main()
