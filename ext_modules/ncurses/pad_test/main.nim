#[
    chekcing how ncurses' pad works
]#

import ncurses

proc main(): void =
    let pwin = initscr()
    let
        pad_row: cint = 10
        pad_col: cint = 64

    keypad(pwin, true);

    # for no input showing on screen
    noecho()
    # disable cursor
    curs_set(0)

    # create 100x100 pad
    var local_pad = newpad(pad_row, pad_col);
    #var local_pad = subpad(local_win, 100, 100, 1, 1)
    #box(local_pad, 0, 0)
    #local_pad.mvwaddch(0,0, chtype(parseUInt("s")))
    #wmove(local_Pad, 1, 1);
    mvwprintw(local_pad, 0, 0, "This is a content in pad for example ...")
    mvwprintw(local_pad, 1, 0, "Pad can be larger than window or ...")
    mvwprintw(local_pad, 2, 0, "prefresh() will draw a prtial or all ...")
    mvwprintw(local_pad, 3, 0, "You need to specify a range to draw by ...")
    mvwprintw(local_pad, 4, 0, "I will talk about super very interesting ...")
    mvwprintw(local_pad, 5, 0, "Marvelous Proof Which This Margin Is Too Narrow ...")
    mvwprintw(local_pad, 6, 0, "Can you prove 1 = 2? I can prove! let's start ...")
    mvwprintw(local_pad, 7, 0, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    mvwprintw(local_pad, 8, 0, "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
    mvwprintw(local_pad, 9, 0, "cccccccccccccccccccccccccccccccccccccccccccccccccccc")

    refresh()

    # prefresh(pad, int pminrow, int pmincol, int sminrow, int smincol, int smaxrow, int smaxcol)
    #[
        let's think of case drawing some pad contents in a window

            `pminrow`, `pmincol` will define the left top of the rendering area in `Pad`

                        pmincol
                       /
                      v
                Pad +-------------------------
                    |This is a content in pad for example ...
          pminrow ->|Pad can be larger than window or ...
                    |prefresh() will draw a prtial or all ...
                    |You need to specify a range to draw by ...
                    |I will talk about super very interesting ...
                    |Marvelous Proof Which This Margin Is Too Narrow ...
                    |Can you prove 1 = 2? I can prove! let's start ...
                    ...

            
            `sminrow`, `smincol`, `smaxrow`, `smaxcol` will define the actual view to draw on window
    
                          smincol         smaxcol
                         /               /
                        v               v
             window +------------------------
                    | 
                    |
          sminrow ->|  *-----------------
                    |  | the contents of|
                    |  | Pad will be    |
                    |  | filled in      |
                    |  | this area      |
          smaxrow ->|  |________________*
                    |


        so, in the case prefresh(pad, pminrow=1, pmincol=1, sminrow=2, smincol=3, smaxrow=5, smaxcol=20)
        the actual view we can see on the screen in `Pad` is

                    pmincol=1
                       /
                      v
                      1
                Pad +-------------------------
                    |This is a content in pad for example ...
        pminrow -> 2|P+----------------+han window or ... 
                    |p| here will be   |w a prtial or all ...
                    |Y| printed on     | a range to draw by ...
                    |I+----------------+uper very interesting ...
                    |Marvelous Proof Which This Margin Is Too Narrow ...
                    |Can you prove 1 = 2? I can prove! let's start ...
                    ...        

        and, what we can see in the terminal is

                          smincol        smaxcol
                         /                /
                        v                v 
                        3               20
             window +------------------------
                    | 
                    |
        sminrow -> 2|   ad can be larger t
                    |   refresh() will dra
                    |   ou need to specify
        smaxrow -> 5|    will talk about s
                    |

        
        run this code, and see in your eyes

    ]#
    let
        pminrow: cint = 1
        pmincol: cint = 1
        sminrow: cint = 2
        smincol: cint = 3
        smaxrow: cint = 5
        smaxcol: cint = 20

        window_row_size = smaxrow-sminrow+1
        window_col_size = smaxcol-smincol+1

        scroll_max = pad_row-window_row_size

    prefresh(local_pad, 1, 1, 2, 3, 5, 20)
    mvprintw(10, 1, "press arrow key, it will change pminrow, pmincol")
    mvprintw(11, 1, "to quit, press q")

    var
        k: int
        mrow: cint = 1
        mcol: cint = 1

    let
        keyQiut = (int64)((chtype)'q')

    while true:
        # return int64 
        k = getch()

        if k == keyQiut:
            break

        elif k == KEY_UP:
            if mrow > 1:
                mrow -= 1

        elif k == KEY_DOWN:
            if mrow < scroll_max:
                mrow += 1

        elif k == KEY_RIGHT:
            mcol += 1

        elif k == KEY_LEFT:
            mcol -= 1

        refresh()
        # move the top-left in pad
        prefresh(local_pad, mrow, mcol, 2, 3, 5, 20)

    endwin()

main()
