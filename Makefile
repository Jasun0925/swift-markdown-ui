check:
	swift run NativeMarkdownCheck

format:
	swift format \
		--ignore-unparsable-files \
		--in-place \
		--recursive \
		./Package.swift \
		./Sources

.PHONY: check format
