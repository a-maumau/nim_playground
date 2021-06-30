CC         = nim c
CFLAGS     =
TARGET     = dijkstra
SRC        = main.nim
# these are for just watching when they are updated
REQUISITES = main_window.nim solver.nim square.nim color_mapper.nim config.nim

$(TARGET): $(SRC) $(REQUISITES)
	$(CC) -o=$@ $(SRC)

$(RUN):
	./$(TARGET)

all: clean $(TARGET) run

run:
	-./$(TARGET)

clean:
	-rm $(TARGET) 
