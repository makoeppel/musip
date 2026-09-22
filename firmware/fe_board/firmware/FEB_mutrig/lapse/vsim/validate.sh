#gnuplot -e "plot 'data_out.txt' using 2:((int(\$2) %8192)-\$4)" -persist
#gnuplot -e "plot 'data_out.txt' using 1:(int(\$4) %1250)" -persist
#gnuplot -e "plot 'data_out.txt' using 1:(int(\$4)- int(\$3))" -persist
#gnuplot -e "plot 'data_out.txt' using 1:((int(\$3)- int(\$2)- 20480)%20480)" -persist
#gnuplot -e "plot 'data_out.txt' using 1:((int(\$6)- int(\$5)- 20480)%20480)" -persist
gnuplot -e "plot 'data_out.txt' using 1:((int(\$9)- int(\$5)))" -persist
