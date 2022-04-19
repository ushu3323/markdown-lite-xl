# Markdown Cheat Sheet

## Basic Syntax

These are the elements outlined in John Gruber’s original design document. All Markdown applications support these elements.

### Heading

# H1
## H2
### H3
#### H4
##### H5
###### H6

### Bold

**bold text** __bold text__

### Italic

*italicized text* _italicized text_

### Blockquote

> blockquote

### Ordered List

1. First item
2. Second item
3) Third item 3) 69. kek

### Unordered List

- First item
- Second item
- Third item

### Unordered List #2

* First item
* Second item
* Third item


### Code

`code`

# Some text with `code` in between
    and a ```c
codeblock
\```

# with more text that has `code in between` ..?!?

# `hello-kebab`

### Code Block

```python
  import tests

  if tests.DoesHighlightingWork() = True:
    print("yay! it works!")
  else
    print("aw man, let's try harder next time")

  # end of file lol
```

### Horizontal Rule

---

***

### Link

[Markdown Guide](https://www.markdownguide.org)

[text lol][1]

[1]: https://www.youtube.com/watch?v=dQw4w9WgXcQ

### Image

![alt text](https://www.markdownguide.org/assets/images/tux.png)

## Extended Syntax

These elements extend the basic syntax by adding additional features. Not all Markdown applications support these elements.

### Table

| Syntax       | Description  |
| ------------ | ------------ |
| Header       | Title        |
| Paragraph    | Text         |

### Footnote

Here's a sentence with a footnote. [^1]

[^1]: This is the footnote.

### Heading ID 

### My Great Heading {#custom-id}

### Definition List

term
: definition

### Strikethrough

~~The world is flat.~~

### Task List

- [x] Write the press release
- [ ] Update the website
- [ ] Contact the media

### Highlight

I need to highlight these ==very important words==.

### Subscript

H~2~O

### Superscript

X^2^
