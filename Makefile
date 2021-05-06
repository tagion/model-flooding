
DC?=dmd
MAIN:=flooding_model

all: $(MAIN)


%: %.d
	$(DC)  $< -of$@

clean:
	rm -f $(MAIN)
