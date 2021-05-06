
import std.math;
import std.random;
import std.stdio;

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
    }
    class Node {
        immutable size_t id;
        private {
            uint _points;
            uint _bucket_no;
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
                }

            }
        }
    }

    uint select_no;
    Selector opCall(const uint points) pure {
        new Node(select_no, points);
        return this;
    }

    pure nothrow {
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
    }
}


int main(string[] args) {
    auto selector=new Selector;


    // Bucket 0 // Active nodes
    selector(10)(12)(11)(9)(1)(17);
    // Bucket 1 // Nodes passive
    selector.select_no=1;
    foreach(i;0..10) {
        selector(10+i);
    }






    // writefln("total_points=%d", selector.total_points);

    auto rnd = Random(unpredictableSeed);


    const samples=5;
    foreach(round;0..samples) {
        Selector.Node active_node;
        Selector.Node passive_node;
        writefln("\n\nRound %d", round);

        { // Select active node
            selector.select_no=0; // Active node bucket
            writefln("Total active %d", selector.total_points);
            const select_point=uniform(0, selector.total_points, rnd);
            writefln("\tpoint %d", select_point);

            active_node=selector.select(select_point);
        }
        { // Select passive node
            selector.select_no=1; // Passive node bucket
            writefln("Total passive %d", selector.total_points);
            const select_point=uniform(0, selector.total_points, rnd);
            writefln("\tpoint %d", select_point);
            passive_node=selector.select(select_point);
        }
        active_node.move(1); // Move active_node to passive node bucket
        passive_node.move(0); // Move passive_node to active node bucket
        //passive_node.points=17;
        writefln("\tMove node %d to passive", active_node.id);
        writefln("\tMove node %d to active", passive_node.id);
    //     //    writefln(""
    }

    return 0;
}
