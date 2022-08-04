#!/usr/bin/env Rscript

################################################
#
# Name: FS_HIPPOCAMPUS_CREATE_INDIVIDUAL_ATROPHY_PLOT_TEMPLATE
#
# Purpose: Template script to read individual FreeSurfer aseg.stats
#   file, create and save atrophy plots. Use SED to replace
#   UPPERCASE_VARIABLES.
#   
# Usage: Set values in USER DEFINED VALUES section at beginning of script.
#
#   WORKING_DIR = directory to save outputs.
#
# Author: J.W. Prescott
# Date: Mar 4, 2016
#
################################################

# suppressPackageStartupMessages(library("optparse"))
suppressPackageStartupMessages(library("ggplot2"))
suppressPackageStartupMessages(library("gamlss"))


setwd( "WORKING_DIR_" )

subject="SUBJECT_"

cat(sprintf("Creating individual brain atrophy report plots for subject %s\n",subject))

# TODO: Load and parse aseg.astats
cat("Loading model file MODEL_FILE_NAME\n")

load(file.path("MODEL_DIR_","MODEL_FILE_NAME"))

#---------
# Calculate normative percentiles, write to file

# Hippocampus
cat("Calculate hippocampus normative percentile\n")
cent.hippo.age = centiles.pred(HIPP_GAMLSS_MODEL_NAME,xname="AGE",xvalues=AgeVar,cent=seq(1,99,1))
idx = findInterval(cent.hippo.age[,2:length(cent.hippo.age)],HippPercICVVar)
idx_match=which(idx!=0)
if(length(idx_match) == 0)
{
  hipp_norm_perc = 99
} else {
  hipp_norm_perc = min(idx_match)	# subject's volume percentile
}

# Lateral Ventricle
cat("Calculate lateral ventricle normative percentile\n")
cent.lat_vent.age = centiles.pred(LAT_VENT_GAMLSS_MODEL_NAME,xname="AGE",xvalues=AgeVar,cent=seq(1,99,1))
idx = findInterval(cent.lat_vent.age[,2:length(cent.lat_vent.age)],LatVentPercICVVar)
idx_match=which(idx!=0)
if(length(idx_match) == 0)
{
  lat_vent_norm_perc = 99
} else {
  lat_vent_norm_perc = min(idx_match)	# subject's volume percentile
}

# Inferior Lateral Ventricle
cat("Calculate inferior lateral ventricle normative percentile\n")
cent.inf_lat_vent.age = centiles.pred(INF_LATERAL_VENT_GAMLSS_MODEL_NAME,xname="AGE",xvalues=AgeVar,cent=seq(1,99,1))
idx = findInterval(cent.inf_lat_vent.age[,2:length(cent.inf_lat_vent.age)],InfLateralVentPercICVVar)
idx_match=which(idx!=0)
if(length(idx_match) == 0)
{
  inf_lat_vent_norm_perc = 99
} else {
  inf_lat_vent_norm_perc = min(idx_match)	# subject's volume percentile
}

# # Hippocampus
# pred_vals = predict(HIPP_RQ_MODEL_NAME,newdata=df.age)
# idx = findInterval(as.vector(pred_vals),HippPercICVVar)
# hipp_norm_perc = min(which(idx != 0))	# subject's volume percentile
# 
# # Inferior Lateral Ventricle
# pred_vals = predict(INF_LAT_VENT_RQ_MODEL_NAME,newdata=df.age)
# idx = findInterval(as.vector(pred_vals),InfLateralVentPercICVVar)
# inf_lat_vent_norm_perc = min(which(idx != 0))	# subject's volume percentile

# save to file
# save to file
h<-file("norm_percentiles.txt")
writeLines(c(sprintf("HippNormPerc %s",hipp_norm_perc),
             sprintf("Hipp5thPerc %.02f",cent.hippo.age$`5`),
             sprintf("Hipp95thPerc %.02f",cent.hippo.age$`95`),
	    sprintf("LatVentNormPerc %s",lat_vent_norm_perc),
	    sprintf("LatVent5thPerc %.02f",cent.lat_vent.age$`5`),
	    sprintf("LatVent95thPerc %.02f",cent.lat_vent.age$`95`),
	    sprintf("InfLateralVentNormPerc %s",inf_lat_vent_norm_perc),
	    sprintf("InfLateralVent5thPerc %.02f",cent.inf_lat_vent.age$`5`),
	    sprintf("InfLateralVent95thPerc %.02f",cent.inf_lat_vent.age$`95`)),
	    h)
close(h)

#---------
# Hippocampal volume plot

cent.hippo = centiles.pred(HIPP_GAMLSS_MODEL_NAME,xname="AGE",xvalues=seq(55,90,1),cent=c(5,25,50,75,95))
names(cent.hippo)[names(cent.hippo)=="x"] = "AGE"
x_new = c(cent.hippo$AGE,cent.hippo$AGE[length(cent.hippo$AGE)],
  cent.hippo$AGE[1],cent.hippo$AGE[1])
y_new_up = c(cent.hippo$`95`,0.8,0.8,cent.hippo$`95`[1])
y_new_down = c(cent.hippo$`5`,0.1,0.1,cent.hippo$`5`[1])
polys = data.frame(x_new,y_new_up,y_new_down)

# TODO: try to get drawing text outside of panel area working.
# Multiple attempts with geom_text and annotation_custom, with
# turning off clipping, don't seem to work
cat("Creating hippocampal volume plot\n")

# p = ggplot(HIPP_MODEL_NAME) +
p = ggplot() + 
  geom_polygon(data=polys, aes(x=x_new,y=y_new_up),
               colour=NA, fill='gray', alpha=0.2) +
  geom_polygon(data=polys, aes(x=x_new,y=y_new_down),
               colour=NA, fill='red', alpha=0.2) +
  geom_smooth(data=cent.hippo, aes(AGE,`95`),
              linetype="dashed", colour="gray") +
  geom_smooth(data=cent.hippo, aes(AGE,`75`),
              linetype="dashed", colour="gray") +
  geom_smooth(data=cent.hippo, aes(AGE,`50`),
              colour="gray") +
  geom_smooth(data=cent.hippo, aes(AGE,`25`),
              linetype="dashed", colour="gray") +
  geom_smooth(data=cent.hippo, aes(AGE,`5`),
              linetype="dashed", colour="red") +
  geom_hline(yintercept=HippPercICVVar, linetype = "dotted", colour="gray", size = 1) +
  geom_vline(xintercept=AgeVar, linetype = "dotted", colour="gray", size = 1) +
  geom_point(aes(x=AgeVar, y=HippPercICVVar), size = 4) +
  # geom_text(aes(label = "95%", x = 89, y = cent.hippo$`95`[length(cent.hippo$`95`)]), hjust = 0, size = 4) +
  # geom_text(aes(label = "75%", x = 89, y = cent.hippo$`75`[length(cent.hippo$`75`)]), hjust = 0, size = 4) +
  # geom_text(aes(label = "50%", x = 89, y = cent.hippo$`50`[length(cent.hippo$`50`)]), hjust = 0, size = 4) +
  # geom_text(aes(label = "25%", x = 89, y = cent.hippo$`25`[length(cent.hippo$`25`)]), hjust = 0, size = 4) +
  # geom_text(aes(label = "5%", x = 89, y = cent.hippo$`5`[length(cent.hippo$`5`)]), hjust = 0, size = 4) +
  ggtitle("Total hippocampal volume (L+R) as percent of ICV vs. age") +
  xlab("Age") +
  ylab("Total hippocampal volume (L+R) as percent of ICV") +
  scale_x_continuous(limits=c(55,90),expand = c(0,0)) +
  scale_y_continuous(limits=c(0.1,0.8),expand = c(0,0)) +
  theme(plot.title = element_text(size=14, face="bold"),
        axis.text.x=element_text(angle=-60,hjust=0),
        axis.text=element_text(size=12,colour="black"),
        axis.title=element_text(size=12,face="bold"),
        axis.line = element_line(colour = "black"),
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        panel.background = element_blank(),
        panel.border = element_rect(linetype = "solid", colour = "black",
                                    fill=NA))

ggsave(filename="hipp_atrophy_plot.png", plot=p)


#---------
# Mean HOC plot

cent.mean_hoc = centiles.pred(MEAN_HOC_GAMLSS_MODEL_NAME,xname="AGE",xvalues=seq(55,90,1),cent=c(5,25,50,75,95))
names(cent.mean_hoc)[names(cent.mean_hoc)=="x"] = "AGE"
x_new = c(cent.mean_hoc$AGE,cent.mean_hoc$AGE[length(cent.mean_hoc$AGE)],
  cent.mean_hoc$AGE[1],cent.mean_hoc$AGE[1])
y_new_up = c(cent.mean_hoc$`95`,1.2,1.2,cent.mean_hoc$`95`[1])
y_new_down = c(cent.mean_hoc$`5`,0.3,0.3,cent.mean_hoc$`5`[1])
polys = data.frame(x_new,y_new_up,y_new_down)

# TODO: try to get drawing text outside of panel area working.
# Multiple attempts with geom_text and annotation_custom, with
# turning off clipping, don't seem to work
cat("Creating mean HOC plot\n")

p = ggplot() + 
  geom_polygon(data=polys, aes(x=x_new,y=y_new_up),
               colour=NA, fill='gray', alpha=0.2) +
  geom_polygon(data=polys, aes(x=x_new,y=y_new_down),
               colour=NA, fill='red', alpha=0.2) +
  geom_smooth(data=cent.mean_hoc, aes(AGE,`95`),
              linetype="dashed", colour="gray") +
  geom_smooth(data=cent.mean_hoc, aes(AGE,`75`),
              linetype="dashed", colour="gray") +
  geom_smooth(data=cent.mean_hoc, aes(AGE,`50`),
              colour="gray") +
  geom_smooth(data=cent.mean_hoc, aes(AGE,`25`),
              linetype="dashed", colour="gray") +
  geom_smooth(data=cent.mean_hoc, aes(AGE,`5`),
              linetype="dashed", colour="red") +
  geom_hline(yintercept=MeanHOCVar, linetype = "dotted", colour="gray", size = 1) +
  geom_vline(xintercept=AgeVar, linetype = "dotted", colour="gray", size = 1) +
  geom_point(aes(x=AgeVar, y=MeanHOCVar), size = 4) +
  # geom_text(aes(label = "95%", x = 89, y = cent.mean_hoc$`95`[length(cent.mean_hoc$`95`)]), hjust = 0, size = 4) +
  # geom_text(aes(label = "75%", x = 89, y = cent.mean_hoc$`75`[length(cent.mean_hoc$`75`)]), hjust = 0, size = 4) +
  # geom_text(aes(label = "50%", x = 89, y = cent.mean_hoc$`50`[length(cent.mean_hoc$`50`)]), hjust = 0, size = 4) +
  # geom_text(aes(label = "25%", x = 89, y = cent.mean_hoc$`25`[length(cent.mean_hoc$`25`)]), hjust = 0, size = 4) +
  # geom_text(aes(label = "5%", x = 89, y = cent.mean_hoc$`5`[length(cent.mean_hoc$`5`)]), hjust = 0, size = 4) +
  ggtitle("Mesial Temporal Lobe (L+R)") +
  xlab("Age") +
  ylab("Mean Hippocampal Occupancy Score (L+R)") +
  scale_x_continuous(limits=c(55,90),expand = c(0,0)) +
  scale_y_continuous(limits=c(0.3,1.2),expand = c(0,0)) +
  theme(plot.title = element_text(size=14, face="bold"),
        axis.text.x=element_text(angle=-60,hjust=0),
        axis.text=element_text(size=12,colour="black"),
        axis.title=element_text(size=12,face="bold"),
        axis.line = element_line(colour = "black"),
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        panel.background = element_blank(),
        panel.border = element_rect(linetype = "solid", colour = "black",
                                    fill=NA))

ggsave(filename="mean_hoc_plot.png", plot=p)

#---------
# Inferior lateral ventricle volume plot

cent.inf_lat_vent = centiles.pred(INF_LATERAL_VENT_GAMLSS_MODEL_NAME,xname="AGE",xvalues=seq(55,90,1), cent=c(5,25,50,75,95))
names(cent.inf_lat_vent)[names(cent.inf_lat_vent)=="x"] = "AGE"
# Polygons to define background color on plot above and below 5%/95% thresholds
x_new = c(cent.inf_lat_vent$AGE,cent.inf_lat_vent$AGE[length(cent.inf_lat_vent$AGE)],
  cent.inf_lat_vent$AGE[1],cent.inf_lat_vent$AGE[1])
y_new_up = c(cent.inf_lat_vent$`95`,0.5,0.5,cent.inf_lat_vent$`95`[1])
y_new_down = c(cent.inf_lat_vent$`5`,0,0,cent.inf_lat_vent$`5`[1])
polys = data.frame(x_new,y_new_up,y_new_down)

# TODO: try to get drawing text outside of panel area working.
# Multiple attempts with geom_text and annotation_custom, with
# turning off clipping, don't seem to work
cat("Creating inferior lateral ventricle volume plot\n")

# p = ggplot(INF_LATERAL_VENT_MODEL_NAME) +
p = ggplot() + 
  geom_polygon(data=polys, aes(x=x_new,y=y_new_up),
               colour=NA, fill='red', alpha=0.2) +
  geom_polygon(data=polys, aes(x=x_new,y=y_new_down),
               colour=NA, fill='gray', alpha=0.2) +
  geom_smooth(data=cent.inf_lat_vent, aes(AGE,`95`),
              linetype="dashed", colour="red") +
  geom_smooth(data=cent.inf_lat_vent, aes(AGE,`75`),
              linetype="dashed", colour="gray") +
  geom_smooth(data=cent.inf_lat_vent, aes(AGE,`50`),
              colour="gray") +
  geom_smooth(data=cent.inf_lat_vent, aes(AGE,`25`),
              linetype="dashed", colour="gray") +
  geom_smooth(data=cent.inf_lat_vent, aes(AGE,`5`),
              linetype="dashed", colour="gray") +
  geom_hline(yintercept=InfLateralVentPercICVVar, linetype = "dotted", colour="gray", size = 1) +
  geom_vline(xintercept=AgeVar, linetype = "dotted", colour="gray", size = 1) +
  geom_point(aes(x=AgeVar, y=InfLateralVentPercICVVar), size = 4) +
  # geom_text(aes(label = "95%", x = 89, y = cent.inf_lat_vent$`95`[length(cent.inf_lat_vent$`95`)]), hjust = 0, size = 4) +
  # geom_text(aes(label = "75%", x = 89, y = cent.inf_lat_vent$`75`[length(cent.inf_lat_vent$`75`)]), hjust = 0, size = 4) +
  # geom_text(aes(label = "50%", x = 89, y = cent.inf_lat_vent$`50`[length(cent.inf_lat_vent$`50`)]), hjust = 0, size = 4) +
  # geom_text(aes(label = "25%", x = 89, y = cent.inf_lat_vent$`25`[length(cent.inf_lat_vent$`25`)]), hjust = 0, size = 4) +
  # geom_text(aes(label = "5%", x = 89, y = cent.inf_lat_vent$`5`[length(cent.inf_lat_vent$`5`)]), hjust = 0, size = 4) +
  ggtitle("Total inferior lateral ventricle volume (L+R) as percent of ICV vs. age") +
  xlab("Age") +
  ylab("Total inferior lateral ventricle volume (L+R) as percent of ICV") +
  scale_x_continuous(limits=c(55,90),expand = c(0,0)) +
  scale_y_continuous(limits=c(0.0,0.5),expand = c(0,0)) +
  theme(plot.title = element_text(size=14, face="bold"),
        axis.text.x=element_text(angle=-60,hjust=0),
        axis.text=element_text(size=12,colour="black"),
        axis.title=element_text(size=12,face="bold"),
        axis.line = element_line(colour = "black"),
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        panel.background = element_blank(),
        panel.border = element_rect(linetype = "solid", colour = "black",
                                    fill=NA))

ggsave(filename="inf_lat_vent_plot.png", plot=p)