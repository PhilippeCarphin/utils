SOURCE = $(wildcard *.c)
EXEC = $(SOURCE:.c=.out)
TEST_STRING = "This is a string that needs to be wrapped, it has a_really_long_word_that_is_too_big for one line"
WRAP_LENGTH = 15
TEST_ARGS = $(TEST_STRING) $(WRAP_LENGTH)

all:$(EXEC)

$(EXEC):$(SOURCE)
	gcc $^ -o $@

.PHONY:test vars
test:$(EXEC)
	./$(EXEC) $(TEST_ARGS)

vars:
	@echo "SOURCE : $(SOURCE)"
	@echo "EXEC : $(EXEC)"
	@echo "TEST_ARGS : $(TEST_ARGS)"
