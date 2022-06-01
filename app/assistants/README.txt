This folder is for classes that get instantiated (unlike managers) that help with something
(but are not ActiveRecord models themselves). Usually, they will contain some functionaly that
could also go into Individual or Property. But for reasons of lightness and decoupling, it might
be good to put their logic into a seperate class.