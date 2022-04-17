# Headers:

# Header 1
## Header 2
### Header 3
#### Header 4
##### Header 5
###### Header 6

## Paragraph:
TODO: wrap text
Lorem ipsum dolor sit amet consectetur adipisicing elit. Doloribus voluptates iste cum quis id perferendis asperiores vero pariatur, ex maiores atque minima praesentium, nulla itaque autem eligendi esse quae voluptatibus.
Voluptas odio consequatur veritatis qui recusandae distinctio eaque repudiandae omnis maxime, impedit provident ipsum voluptates sit magni eveniet sed accusamus optio laboriosam officia, illo ab quaerat culpa. Voluptatem, culpa corrupti.

##                    Codeblock

    local function markdown_code_example(foo, bar, table)
      -- Todo: add syntax highlighting (probably using lite-xl syntax settings)
      print("Hello markdown!")
      
      local isMarkdown = true
      for key, value in pairs(table) do
        core.log("key: %s | value: %s", key, value)
      end
      
      return isMarkdown
    end
    
```lua
  local foo = "bar"
  print(foo) -- Output: bar
```

## Lists:
### Unorderer list:
- List Item 1
- List Item 2
- List Item 3
- List Item 4

## Ordered list:
1. List Item 1
1. List Item 2
1. List Item 3



# MORE TODO:

TODO: change listitem dot style depending on indentation depth
TODO: add margin
    - Nodo 1 but shown as codeblock
- Node 2
  - sub node 1 of node 1
  - sub-node 2 of node 1
    - sub-sub-node 1 of sub-node 2 of node 1
      - sub-sub-sub-node 1 of sub-sub-node 1 of sub-node 2 of node 1
        - sub-sub-sub-node 1 of sub-sub-node 1 of sub-node 2 of node 1
          - sub-sub-sub-node 1 of sub-sub-node 1 of sub-node 2 of node 1
            - sub-sub-sub-node 1 of sub-sub-node 1 of sub-node 2 of node 1
              - sub-sub-sub-node 1 of sub-sub-node 1 of sub-node 2 of node 1
                - sub-sub-sub-node 1 of sub-sub-node 1 of sub-node 2 of node 1
  - sub-node 3 of node 1
- Node 3

      - Node 1 but shown as codeblock


