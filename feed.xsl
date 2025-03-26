<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd" xmlns:content="http://purl.org/rss/1.0/modules/content/">
 <xsl:output method="html" version="1.0" encoding="UTF-8" indent="yes"/>
 <xsl:template match="/">
  <html xmlns="http://www.w3.org/1999/xhtml">
   <head>
    <title><xsl:value-of select="/rss/channel/title"/> RSS</title>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <link rel="stylesheet" href="/assets/css/feed.css" />
   </head>
   <body>
    <div class="container">
     <div class="podcast-header">
      <h1>
       <xsl:if test="/rss/channel/image">
        <div class="podcast-image">
         <a>
          <xsl:attribute name="href">
           <xsl:value-of select="/rss/channel/image/link"/>
          </xsl:attribute>
          <img>
           <xsl:attribute name="src">
            <xsl:value-of select="/rss/channel/image/url"/>
           </xsl:attribute>
           <xsl:attribute name="title">
            <xsl:value-of select="/rss/channel/image/title"/>
           </xsl:attribute>
          </img>
         </a>
        </div>
       </xsl:if>
       <xsl:value-of select="/rss/channel/title"/>
      </h1>
      <p>
       <xsl:value-of select="/rss/channel/description" disable-output-escaping="yes"/>
      </p>
     </div>
     <xsl:for-each select="/rss/channel/item">
      <div class="item">
       <h2>
        <a>
         <xsl:attribute name="href">
          <xsl:value-of select="link"/>
         </xsl:attribute>
         <xsl:attribute name="target">_blank</xsl:attribute>
         <xsl:value-of select="title"/>
        </a>
       </h2>
       <div class="meta">
        <span><xsl:value-of select="pubDate" /></span>
       </div>
       <xsl:if test="description">
        <p class="description" style="white-space: pre-line;">
         <xsl:value-of select="description" disable-output-escaping="yes"/>
        </p>
       </xsl:if>
       <xsl:choose>
        <xsl:when test=" description = content:encoded">
        </xsl:when>
        <xsl:otherwise>
         <p class="content">
          <xsl:value-of select="content:encoded" disable-output-escaping="yes"/>
         </p>
        </xsl:otherwise>   
       </xsl:choose>       
       <!-- audio controls="true" preload="none">
        <xsl:attribute name="src">
        <xsl:value-of select="enclosure/@url"/>
        </xsl:attribute>
       </audio -->
      </div>
     </xsl:for-each>
    </div>
   </body>
  </html>
 </xsl:template>
</xsl:stylesheet>
