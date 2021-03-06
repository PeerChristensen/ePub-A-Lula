
# Shiny
library(shiny)
library(shinythemes)
library(shinybusy)
# Text
library(textrank)
library(reticulate)
library(spacyr)
library(tidytext)
library(sentimentr)
library(udpipe)
library(quanteda)
# Data
library(igraph)
library(ggraph)
library(epubr)
library(data.table)
library(tidyverse)
library(networkD3)
library(widyr)

red <- "#C41A24"
#use_python("/Users/peerchristensen/.pyenv/versions/3.7.3")
spacy_initialize(model="en_core_web_lg")


# ---------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------

ui <- fluidPage(theme = shinytheme("slate"),
                add_busy_spinner(spin = "fading-circle",margin=c(40,30),color="snow"),#add_busy_bar(color = "snow"),

           titlePanel(h1("ePub - A - Lula",align="center",
                         style='color: snow;
                         font-family: Roboto Condensed;
                         font-size: 45px;
                         font-weight: bold;
                         background-color:#C41A24;
                         padding-bottom: 20px;
                         padding-top: 20px')),
           fluidRow(
               column(12,
                      fileInput("file", h3("Upload ePub"),accept = ".epub",
                         placeholder="",width="25%"),align="center", 
                         style='padding:20px;
                                color: snow;
                                font-size: 18px;
                                font-weight: bold;
                                font-family: Roboto Condensed;')),
           splitLayout(
               h3("Author",align="center",
                    style='color: snow;font-family: Roboto Condensed;'),
               h3("Title",align="center",
                   style='color: snow;font-family: Roboto Condensed;'),
               h3("Genre",align="center",
                   style='color: snow; font-family: Roboto Condensed;'),
               h3("Publisher",align="center",
                   style='color: snow; font-family: Roboto Condensed;'),
               h3("ISBN",align="center",
                   style='color: snow;font-family: Roboto Condensed;'),
               h3("Date",align="center",
                   style='color: snow;font-family: Roboto Condensed;')),
        splitLayout(
               h4(textOutput("author"),align="center",
                   style='color: snow;font-family: Roboto Condensed;'),
                h4(textOutput("title"),align="center",
                    style='color: snow;font-family: Roboto Condensed;'),
                h4(textOutput("genre"),align="center",
                    style='color: snow;font-family: Roboto Condensed;'),
                h4(textOutput("publisher"),align = "center",
                    style='color: snow;font-family: Roboto Condensed;'),
                h4(textOutput("isbn"),align = "center",
                    style='color: snow;font-family: Roboto Condensed;'),
                h4(textOutput("date"),align = "center",
                    style='color: snow;font-family: Roboto Condensed;')),
        hr(),
        fluidRow(
            column(12,
                h3("Readability",align="center",
                    style='color: snow; font-weight: bold;font-family: Roboto Condensed;')
                )
            ),
        fluidRow(
            column(2,
                h4("Difficult"),align="right",
                    style='color: snow; font-weight: bold;font-family: Roboto Condensed;'),
             column(8,
                    plotOutput("readability",width = "100%",height = "170px"),align="center"),
             column(2,
                h4("Easy"),align="left",
                    style='color: snow; font-weight: bold;font-family: Roboto Condensed;')
        ),
        hr(),
        fluidRow(
            column(5,
                   h3("Keywords",align="center",
                        style='color: snow; font-weight: bold; font-family: Roboto Condensed;')),
            column(7,
                   h3("Sentiment structure",align="center",
                        style='color: snow; font-weight: bold;font-family: Roboto Condensed;'))
        ),
        fluidRow(
            column(5, plotOutput("keywords",width = "90%"),align="center"),
            column(7, plotOutput("sentiment",width = "90%"),align="center")
        ),
        hr(),
        fluidRow(
            column(12, 
                h3("Named entities"),align="center",
                    style='color: snow; font-weight: bold;font-family: Roboto Condensed;')),
        fluidRow(
            column(12,offset=2,align="center",
                   mainPanel(
                       tabsetPanel(
                            tabPanel("Frequency",
                                plotOutput("ner",width = "100%",height = "1000px")),
                            tabPanel("Co-occurence Network",
                                forceNetworkOutput("cooc",width = "100%",height = "1200px")
                                )
                            )
                       )
                   )
              ),
        hr()
)

# ---------------------------------------------------------------------
# SERVER
# ---------------------------------------------------------------------

server <- function(input, output) {
    
    # input data
    observe({
        file = input$file

        if (is.null(file)) {
            return(NULL)
        }
    df <- epub(file$datapath)
    meta  <- df
    df <- df$data[[1]]
    
    # one row
    df_row <- tibble(text = paste(df$text,collapse = ","))
    
    # sentences
    # df_sentences <- df$data[[1]] %>%
    #      unnest_tokens(output = sentences, input = text,token = "sentences",to_lower = F) %>%
    #      mutate(sentences = tm::removePunctuation(sentences))
    
    # sentences <-spacy_tokenize(
    #     df$text,
    #     what = c("sentence"),
    #     remove_punct = TRUE,
    #     remove_url = TRUE,
    #     remove_numbers = TRUE,
    #     remove_separators = TRUE,
    #     remove_symbols = TRUE,output="data.frame") %>%
    #     as_tibble() %>%
    #     mutate(sentence_id = row_number())
    
    # annotated
    #anno <- spacy_parse(sentences$token)
    anno <- spacy_parse(df$text)
    
    # Meta data
    output$author    <- renderText(meta$creator)
    output$title     <- renderText(meta$title)
    output$genre     <- renderText(meta$subject)
    output$publisher <- renderText(meta$publisher)
    output$isbn      <- renderText(meta$identifier)
    output$isbn      <- renderText(meta$identifier)
    output$date      <- renderText(as.character(as.Date(meta$date)))
    
    # Keywords
    stats <- textrank_keywords(anno$token,
                               relevant = anno$pos %in% c("NOUN", "ADJ"),
                               ngram_max = 5, sep = " ")
    stats <- subset(stats$keywords, ngram > 1 & freq >= 5)
    top_tr <- stats %>%
        top_n(5,freq)
    # stats2 <- keywords_rake(x = anno,
    #                         term = "lemma", group = c("doc_id"),
    #                         relevant = anno$pos %in% c("NOUN", "ADJ"),
    #                         ngram_max = 8)
    # top_rake <-stats2 %>%
    #     filter(freq >=5) %>%
    #     top_n(5,rake) %>%
    #     select(-rake)
    #keywords <- rbind(top_tr,top_rake) %>%
    keywords <- top_tr %>%
        distinct(keyword, .keep_all = T) %>%
        arrange(desc(freq)) %>%
        mutate(order = rev(row_number()))
    output$keywords  <- renderPlot({
        keywords %>%
            ggplot(aes(order,freq)) +
            geom_col(fill=red,width=.7) +
            coord_flip() +
            scale_x_continuous(breaks = keywords$order,
                               labels = keywords$keyword) +
            theme(axis.text = element_text(family = "Roboto Condensed",
                                           colour = "snow",size = 16),
                  axis.title = element_blank(),
                  plot.background = element_rect(fill="#272B30",
                                                 color = "#272B30", size = 0),
                  panel.background = element_rect(fill="#272B30",
                                                  color = "#272B30", size = 0),
                  panel.grid = element_blank())
    })
    
    # Sentiments
    sentiments      <- sentiment(get_sentences(df_row$text))
    sentiments$part <- cut(sentiments$sentence_id, breaks = 1000,labels=1:1000)
    
    sentiments <- sentiments %>%
        group_by(part) %>%
        summarise(m = mean(sentiment)) %>%
        mutate(rollmean = frollmean(m, n = 50, fill = 0, align = "right"))
    
    output$sentiment <- renderPlot({
        sentiments %>%
            ggplot(aes(as.numeric(part),rollmean)) +
            geom_col(colour="snow",alpha=.01,width=.2) +
            geom_smooth(se=F,colour=red,size=2.5,method="gam") +
            theme_void() +
            theme(plot.background  = element_rect(fill="#272B30"),
                  panel.background = element_rect(fill="#272B30",
                                                  color = "#272B30", size = 0),
                  panel.grid = element_blank())
    })
    
    # readability
    dfCorpus <- quanteda::corpus(df_row,  text_field = "text")
    readability <- quanteda::textstat_readability(dfCorpus,
                                                  measure = c("Flesch")) %>%
        as_tibble() %>%
        select(Flesch) %>%
        mutate(row="a")
    output$readability <- renderPlot( {
        readability %>%
            ggplot(aes(row,max)) +
            geom_col(width=.4, fill = "#1a9850",aes(row,100),colour="lightgrey") +
            geom_col(width=.4, fill = "#a6d96a",aes(row,90),colour="lightgrey") +
            geom_col(width=.4, fill = "#d9ef8b",aes(row,80),colour="lightgrey") +
            geom_col(width=.4, fill = "#fee08b",aes(row,70),colour="lightgrey") +
            geom_col(width=.4, fill = "#fdae61",aes(row,60),colour="lightgrey") +
            geom_col(width=.4, fill = "#f46d43",aes(row,50),colour="lightgrey") +
            geom_col(width=.4, fill = "#d73027",aes(row,30),colour="lightgrey") +
            geom_hline(yintercept = readability$Flesch, size = 9,colour="lightgrey") +
            geom_hline(yintercept = readability$Flesch, size = 7,colour="snow") +
            coord_flip() +
            theme_void() +
            theme(plot.margin = margin(2, 0, 2, 0, "cm"),
                plot.background = element_rect(fill="#272B30",
                                               color = "#272B30", size = 0),
                panel.background = element_rect(fill="#272B30",
                                                color = "#272B30", size = 0))
    })
    
    # NER
    ents_full <- entity_extract(anno) %>%
        filter(entity_type %in% c("GPE","FAC","NORP","PERSON")) %>%
        mutate(entity = str_replace_all(entity,"_"," "))
    ents <- ents_full %>%
        group_by(entity_type) %>%
        count(entity) %>%
        group_by(entity) %>%
        arrange(desc(n)) %>%
        top_n(1,n)
    ents_plot <- ents %>%
        group_by(entity_type) %>%
        count(entity) %>%
        top_n(8,n) %>%
        ungroup()     %>%
        arrange(entity_type, -n) %>%
        filter(n>=2) %>%
        mutate(order = rev(row_number()),
               colour = case_when(entity_type == "FAC"    ~ "goldenrod",
                                  entity_type == "GPE"    ~ "forestgreen",
                                  entity_type == "NORP"   ~ "blue3",
                                  entity_type == "PERSON" ~ "#C41A24")) 
    pairs <- ents_full %>%
        widyr::pairwise_count(entity, doc_id, sort = TRUE)
    network <- pairs %>%
        top_frac(.1) %>%
        top_n(250,n) %>%
        graph_from_data_frame() %>%
        igraph_to_networkD3()
    network$nodes <- network$nodes %>%
        left_join(ents, by = c("name" = "entity"))
    output$ner <- renderPlot({
        ents_plot %>%
            ggplot(aes(order,n)) +
            geom_col(width=.7,fill=ents_plot$colour) +
            scale_x_continuous(
                breaks = ents_plot$order,
                labels = ents_plot$entity,
                expand = c(0,0)) +
            facet_wrap(~entity_type,scales="free") +
            coord_flip() +
            theme_void() +
            theme(axis.text.y =element_text(size=16,family="Roboto Condensed",colour = "snow"),
                  strip.text = element_text(size=20,family="Roboto Condensed",vjust=7),
                  panel.spacing = unit(2, "cm"),
                  strip.text.x = element_text(margin = margin(t = 30),colour="snow"),
                  axis.text.x = element_blank(),
                  plot.margin = margin(1, 0, 0, 0, "cm"),
                  plot.background = element_rect(fill="#272B30",
                                                 color = "#272B30", size = 0),
                  panel.background = element_rect(fill="#272B30",
                                                  color = "#272B30", size = 0))
    })
    output$cooc <- renderForceNetwork({

        my_color <- 'd3.scaleOrdinal() .domain(["PERSON", "NORP","GPE", "FAC"]) .range(["#C41A24", "blue" , "green", "yellow"])'

        forceNetwork(Links = network$links, Nodes = network$nodes,
                     Source = 'source', Target = 'target',
                     NodeID = 'name', Group = 'entity_type',
                     Value='value', Nodesize = 'n',fontSize=35,
                     colourScale = my_color, zoom = T,
                     fontFamily = "Roboto Condensed", linkDistance = 100,
                     linkColour = "snow")
    })
    })
}

# Run the application 
shinyApp(ui = ui, server = server)
