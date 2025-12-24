-- SWITCH TO postgres SYSTEM USER
sudo -i -u postgres

-- OPEN postgreSQL SHELL
psql

-- CREATE USER WITH NAME nodeuser AND PASSWORD mypassword233
CREATE USER nodeuser WITH PASSWORD 'mypassword233';


-- CREATE DATABASE
CREATE DATABASE world;

-- GRANT PRIVILEGES 
GRANT ALL PRIVILEGES ON DATABASE world TO nodeuser;

-- EXIT postgreSQL SHELL
\q







CREATE DATABASE world;

CREATE TABLE quiz (
    id SERIAL PRIMARY KEY,
    questions TEXT NOT NULL,
    answers TEXT NOT NULL
);

INSERT INTO quiz (questions, answers) VALUES
('What is the capital city of Japan?', 'Tokyo'),
('Which planet is known as the Red Planet?', 'Mars'),
('What is the largest mammal on Earth?', 'Blue Whale'),
('Who painted the Mona Lisa?', 'Leonardo da Vinci'),
('What is the smallest country in the world?', 'Vatican City'),
('What is the chemical symbol for Gold?', 'Au'),
('How many days are there in a leap year?', '366'),
('Which continent is the Sahara Desert located in?', 'Africa'),
('What is the fastest land animal?', 'Cheetah'),
('In which country did the Olympic Games originate?', 'Greece'),
('Who wrote “Romeo and Juliet”?', 'William Shakespeare'),
('What is the hardest natural substance on Earth?', 'Diamond'),
('How many continents are there?', 'Seven'),
('What is the largest ocean in the world?', 'Pacific Ocean'),
('What gas do plants absorb from the atmosphere?', 'Carbon Dioxide'),
('What is the tallest mountain in the world?', 'Mount Everest'),
('What currency is used in the United Kingdom?', 'Pound Sterling'),
('Which animal is known as the King of the Jungle?', 'Lion'),
('What is H2O commonly known as?', 'Water'),
('Who invented the telephone?', 'Alexander Graham Bell');
