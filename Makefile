VALAC = valac
LIBS = libsoup-2.4 gee-1.0 json-glib-1.0 posix
OPTS  = --thread -g
RM    = rm -f

TARGET = Miner
VLIBS   = $(patsubst %,--pkg %,$(LIBS))

all:$(TARGET)

$(TARGET): $(TARGET).vala
	$(VALAC) $(OPTS) $(VLIBS) $(TARGET).vala

clean:
	$(RM) $(TARGET)
