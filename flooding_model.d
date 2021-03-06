
import std.math;
import std.random;
import std.stdio;
import std.algorithm.iteration : filter, each;

@safe
struct FermiDirac {
    double threashold;
    double gain; // 1/kBT
    double opCall(const double x) const pure nothrow {
        return 1.0/(1.0+exp(gain*(x-threashold)));
    }
}


@safe
class Selector {
    private {
        uint node_id;
        uint[uint] _total_points;
        Node[] _nodes;
        int _round_no;
    }
    class Node {
        immutable size_t id;
        bool evil;
        private {
            uint _points;
            uint _bucket_no;
            int _round_no;
        }
        this(const uint bucket_no, const uint v) pure {
            _bucket_no=bucket_no;
            _points=v;
            _total_points.update(bucket_no,
                {
                    return v;
                },
                (ref uint points) {
                    points+=v;
                    return points;
                });
            id=node_id++;
            _nodes~=this;
        }
        pure nothrow {
            uint points() const {
                return _points;
            }

            void points(const uint v) {
                if (v != _points) {
                    _total_points[_bucket_no]+=v-_points;
                    _points=v;
                }
            }

            double probability() const {
                return double(_points)/double(_total_points[_bucket_no]);
            }

            void move(const uint to_bucket_no) {
                if (to_bucket_no !is _bucket_no) {
                    scope(exit) {
                        _bucket_no=to_bucket_no;
                    }
                    _total_points[to_bucket_no]+=_points;
                    _total_points[_bucket_no]-=_points;
                    _round_no = this.outer._round_no;
                }

            }

            uint bucket_no() const{
                return _bucket_no;
            }

            int round_no() const{
                return _round_no;
            }

        }
    }

    uint select_no;
    Node opCall(const uint points) pure {
        return new Node(select_no, points);
    }
    const(Node[]) opSlice() const pure nothrow {
        return _nodes;
    }
    pure nothrow {
        void next_round() {
            _round_no++;
        }
        uint total_points() const {
            return _total_points[select_no];
        }

        Node select(const uint select_points)
            in {
                assert(select_points < _total_points[select_no], "select_ppoits too large");
            }
        do {
            uint accumulate_points;
            foreach(ref n; _nodes) {
                if (n._bucket_no == select_no) {
                    accumulate_points+=n.points;
                    if (accumulate_points > select_points) {
                        return n;
                    }
                }
            }
            assert(0);
        }
        uint count_evil(const uint no) const {
            uint result;
            _nodes
                .filter!(a => (a.bucket_no==no && a.evil))
                .each!(a => result++);
            return result;
        }
        uint count(const uint no) const {
            uint result;
            _nodes
                .filter!(a => (a.bucket_no==no ))
                .each!(a => result++);
            return result;
        }

        uint round_no() const{
            return _round_no;
        }

    }
}

int main(string[] args) {
    auto selector=new Selector;

// Write to csv
    auto f = File("test.csv", "w");
    scope(exit) {
        f.close;
    }

    // Bucket 0 // Active nodes
    foreach(i;0..750) {
        selector(40);
    }
    // Bucket 1 // Nodes passive
    selector.select_no=1;
    foreach(i;0..1000) {
        selector(40);
    }
    //Defines evil nodes in passive
    foreach(i;0..3250) {
        selector(1).evil=true;
    }


    // writefln("total_points=%d", selector.total_points);

    auto rnd = Random(unpredictableSeed);

    const samples=100000;

    foreach(round;0..samples) {
        Selector.Node active_node;
        Selector.Node passive_node;
        scope(exit) {
            selector.next_round;
        }
        writefln("\n\nRound %d", selector.round_no);

        { // Select active node - //Lets change to random between node id instead of based on points
            selector.select_no=0; // Active node bucket
            writefln("Total active points %d", selector.total_points);
            const select_point=uniform(0, selector.total_points, rnd);
            writefln("\tpoint %d", select_point);
            active_node=selector.select(select_point);
        }

        { // Select passive node
            selector.select_no=1; // Passive node bucket
            writefln("Total passive points %d", selector.total_points);
            const select_point=uniform(0, selector.total_points, rnd);
            writefln("\tpoint %d", select_point);
            passive_node=selector.select(select_point);

        }
        writefln("Number of round active %d", selector.round_no - active_node.round_no);
        writefln("Number of round passive %d", selector.round_no - passive_node.round_no);

        active_node.move(1); // Move active_node to passive node bucket
        passive_node.move(0); // Move passive_node to active node bucket
        writefln("Move node %d to passive", active_node.id);
        writefln("Move node %d to active", passive_node.id);

        // Evil nodes in active
        writefln("count evil nodes in active=%d", selector.count_evil(0));

        // Evil nodes in passive
        writefln("count evil nodes in passive=%d", selector.count_evil(1));

        // print to csv file
        f.writefln("%d, %d, %d,", round, selector.count_evil(0), selector.count(0));

    }



    return 0;
}
