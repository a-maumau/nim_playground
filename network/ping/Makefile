CC         = nim c
CFLAGS     =
TARGET     = ping
SRC        = main.nim
# these are for just watching when they are updated
REQUISITES = ping.nim

$(TARGET): $(SRC) $(REQUISITES)
	$(CC) -o=$@ $(SRC)

$(RUN):
	./$(TARGET)

all: clean $(TARGET) run

run:
	-./$(TARGET)

clean:
	-rm $(TARGET) 
