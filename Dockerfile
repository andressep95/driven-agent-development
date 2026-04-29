FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline -q
COPY src src
RUN mvn package -q -DskipTests

FROM eclipse-temurin:21-jre
COPY --from=build /app/target/agent.jar /usr/local/lib/agent.jar
ENTRYPOINT ["java", "-jar", "/usr/local/lib/agent.jar"]
