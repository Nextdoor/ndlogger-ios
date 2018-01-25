FROM swift:4.0.3
MAINTAINER Abhijeet Kumar 
LABEL Description="Image for building and running Logging library for iOS" 

ADD Sources Sources
ADD Package.swift Package.swift
ADD Tests Tests 

CMD swift test
