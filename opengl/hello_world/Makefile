CC         = nim c
CFLAGS     =
TARGET     = hello_world
SRC        = main.nim
# these are for just watching when they are updated
REQUISITES =

$(TARGET): $(SRC) $(REQUISITES)
	$(CC) -o=$@ $(SRC)

$(RUN):
	./$(TARGET)

all: clean $(TARGET) run

run:
	-./$(TARGET)

clean:
	-rm $(TARGET) 
