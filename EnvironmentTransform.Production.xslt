<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:transform xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:sc="http://schemas.microsoft.com/ServiceHosting/2008/10/ServiceConfiguration" version="1.0">
    <xsl:template match="@*|node()">
        <xsl:copy>
            <xsl:apply-templates select="@*|node()"/>
        </xsl:copy>
    </xsl:template>
  
  <xsl:template match="//sc:Setting[@name='ENVIRONMENT']">
    	<xsl:copy>
    		<xsl:attribute name="value">
    			<xsl:text>PRODUCTION</xsl:text>
    		</xsl:attribute>
    	</xsl:copy>
    </xsl:template>
</xsl:transform>